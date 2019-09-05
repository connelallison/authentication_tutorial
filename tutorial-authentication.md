Tutorial: Authentication
========

### Introduction

This tutorial will guide you through adding a user system and authentication to the blog site you built in the [RESTful](tutorial-restful-blog.md) and [Validation](tutorial-validation.md) tutorials. This assumes you have completed those tutorials and will add to the code you used there.

## Authentication

Authentication is an essential feature of most websites - without it users can read, modify, or delete data they should not have access to. You may wish to read through this [thorough explanation of authentication](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) before continuing.

In this tutorial, we will allow users to sign up for an account and post blogs under their own name. Blogs will link to their author and authors to their blogs, and it will only be possible to edit or delete a blog or user when logged in as the appropriate user.

## Updating the database

Before we can think about any tcl code for our new user system, we will need to prepare the database. It will not be necessary to create a new table for users, as one was added for you when you first ran `db_init` to initialise the database. To confirm this, run `\d+ users` in psql.

You will notice that in addition to storing a first and last name and an email address, we also store a [password hash](https://security.blogoverflow.com/2013/09/about-secure-password-hashing/). We do not store the password itself, as this would mean an unmitigated loss of security in the event of attackers accessing the database. Instead, we store a hash, and when a user tries to use their password we simply hash what they submit and compare it to the hash we have stored: if the hashes match, the passwords do too. If someone gains access to the database and the collection of password hashes, on the other hand, it should be difficult for them to turn a hash back into a user's password.

Also of note is the "user_state" column. As various other tables reference the users table, we do not actually want to delete our users. Instead, when we want them to be "deleted" from the site, we will set their user_status to 'DISABLED', and our other queries will be written so as to exclude any deactivated users from the results.

It is also worth taking note of the anonymous user. Run `select * from users;` to see the current collection of users. There should only be one - an anonymous user with a user_id of -1. When a user is not logged in, they will be treated as the anonymous user, and any other table that references a user_id, such as the session table, will use -1. It is important to treat this special user carefully - for example, we must make sure it cannot be deleted or modified, we must avoid listing it in an index with the other users, and we must ensure anonymous users do not have the same control over anonymous entries that a user has over that user's entries.

Though most of the work has been done for us, there are still some changes we should make to our database before moving on. First, we should change our email column so that each row must be unique - it will not do for us to allow multiple accounts to be made under the same email address. Run the following command in psql:

```sql
ALTER TABLE users ADD UNIQUE (email);
```

We will also want to change the entries table to include an author column so that we have a record of which entries were posted by which users. Run the following command in psql:

```sql
ALTER TABLE entries ADD COLUMN entry_author INT REFERENCES users(user_id) DEFAULT -1;
```

From now on, whenever a user adds a new entry, their user_id will be recorded with it. If there is no user logged in, it will default to the anonymous user_id, -1 - in fact, if you check the entries table you should see that all the entries we inserted before adding this column have had their entry_author field helpfully filled in with the default value.

We will need to revisit the database again later, but this will do for the time being. We can now begin writing our tcl code.

## Helpers

Before we write procs and handlers for dealing with users, we should take the opportunity to clean up our code a little. In the previous tutorial, we attached scripts and stylesheets on the two pages which contained a form. During this tutorial we will be adding many more forms and it is also good to have consistent styling between pages, so we will apply these scripts to every page. However, reproducing all the code required to do so, in full (more than thirty lines), in every single path handler would make our files horrendously cluttered with redundant code. Instead, create a new file in the same directory as `url_handlers.tcl` and `entry.tcl`, called `helpers.tcl`. First, add the following proc:

```tcl
proc imports_helper {} {
    #| Returns the scripts and stylesheets used on every page as a single variable
    set imports ""
    append imports [h script type "text/javascript" \
			src "https://code.jquery.com/jquery-1.9.1.min.js"]
    append imports [h script type "text/javascript" \
			src "https://code.jquery.com/ui/1.9.2/jquery-ui.min.js"]
    append imports [h script type "text/javascript" \
			src "https://cdn.jsdelivr.net/npm/js-cookie@2/src/js.cookie.min.js"]
    append imports [h script type "text/javascript" \
			src "https://cdnjs.cloudflare.com/ajax/libs/qtip2/3.0.3/jquery.qtip.min.js"]
    append imports [h script type "text/javascript" \
			src "https://d1ab3pgt4r9xn1.cloudfront.net/qcode-ui-4.34.0/js/qcode-ui.js"]

    append imports [h script type "text/javascript" \
			src "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"]
    append imports [h link rel stylesheet type "text/css" \
			href "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css"]
    append imports [h link rel stylesheet type "text/css" \
			href "https://js.qcode.co.uk/vendor/qtip/2.2.1/jquery.qtip.min.css"]
    append imports [h link rel stylesheet type "text/css" \
			href "https://js.qcode.co.uk/qcode-ui-4.13.0/css/qcode-ui.css"]

    return $imports
}
```

We can now use this proc to append all of our scripts and stylesheets in one command. Go ahead and replace your imports with `append html [imports_helper]`, and then put it at the top of your HTML for the pages that do not have it yet. Check to confirm that the styling has applied correctly on all your pages, and that everything still works as it should. Then, add the following to `helpers.tcl`:

```tcl
proc validation_helper {form_id} {
    #| Returns the script used for every form to set up validation
    return [h script type "text/javascript" " 
	    \$('#$form_id').validation({
		submit: false, messages: {error: {before: '#$form_id'}}
	    });
    	        	 
    	    \$('#$form_id').on('validationComplete', function(event) {
		const response = event.response;
		if (response.status === 'valid') {
		    \$(this).validation('setValuesFromResponse', response);
		    \$(this).validation('showMessage', 'notify', 'Submitted');
		} else {
		    \$(this).validation('showMessage', 'error', 'Invalid values');
		}
	    });
	"]
}
```

In much the same way, this proc will replace writing out your script each time you set up validation on a form. This proc takes the id of the form as an argument, and then returns all the HTML you will need to set up validation on that form. Replace your validation scripts with the new proc, and then confirm your validation is still working correctly. Your pages should all now have consistent styling, and your code should be neater (and remain so as we continue to add more pages and forms).

## Creating users

The first page we will need to implement our user system will be a form for new users to sign up. In your `url_handlers.tcl` file, add the following:

```tcl
register GET /users/new {} {
    #| Form for signing up as new user
    set html ""
    append html [imports_helper]
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]

    if { $session_user_id == -1 } {
	set form ""
	append form [h label "First Name:"]
	append form [h br]
	append form [h input type text name firstname]
	append form [h br]
	append form [h label "Last Name:"]
	append form [h br]
	append form [h input type text name surname]
	append form [h br]
	append form [h label "Email Address:"]
	append form [h br]
	append form [h input type text name email]
	append form [h br]
	append form [h label "Enter Password:"]
	append form [h br]
	append form [h input type password name password]
	append form [h br]
	append form [h label "Repeat Password:"]
	append form [h br]
	append form [h input type password name confirm_password]
	append form [h br]
	append form [h br]    
	append form [h input type submit name submit value Submit]

	append html [qc::form id "new-user-form" method POST action /users $form]
	append html [validation_helper "new-user-form"]
    } else {	
	append html [h p "You are already logged in."]
    }
    return $html   
}
```

This is reasonably similar to our previous forms, but a few things are worth drawing attention to. You will notice that the form is only appended conditionally - we use `session_id` to retrieve the session_id, and then `session_user_id` to then retrieve the user_id of the current user, and we then check to confirm that the current user is not already logged in. If they are not an anonymous user (but have somehow reached this page) the form is replaced with a message noting that they are already logged in. Note also that we have used the "password" input type to obscure the password as it is entered, and that we also require the password to be entered twice when it is first set, as is good practice to prevent users inadvertently setting a mistyped password.

Next we must create our POST handler for the form to be submitted to. Add the following to your `url_handlers`:

```tcl
register POST /users {firstname surname email password confirm_password} {
    #| Create a new user
    set user_id [user_create $firstname $surname $email $password $confirm_password]
    set session_id [session_new $user_id]
    cookie_set session_id $session_id
    cookie_set authenticity_token [session_authenticity_token $session_id] http_only false    
    qc::response action redirect [qc::url "/users/$user_id"]  
}
```

Here we pass the details submitted in the form to our  `user_create` proc which will be responsible for validating them, storing them in the database, and then returning the user_id of the newly created user. The path handler, assuming there were no issues with the data submitted, will then create a new session_id using the user_id, and store it (along with an authenticity token) in a cookie, logging the user into their new account - before redirecting them to their new user page.

Next we must add our `user_create` proc. In a new file called `user.tcl`, place the following code:

```tcl
proc user_create {firstname surname email password confirm_password} {
    #| Create a new user
    set user_id [db_seq user_id_seq]
    if {$password ne $confirm_password} {
    	error "Your passwords do not match." {} USER
    }
    password_complexity_check $password min 4 max 20 minclasses 1
    db_1row {select crypt(:password, gen_salt('bf', 7)) as password_hash}
    
    db_dml "insert into users\
           [sql_insert user_id firstname surname email password_hash]"
    return $user_id    
}
```

Here we check to make sure that the two passwords the user submitted match, and that they meet certain complexity restrictions - for testing purposes, we are requiring that passwords be at least 4 and at most 20 characters long, and we do not require a mix of character types. In practice, of course, this would be a very low standard of security and would permit some dangerously weak passwords.

After validating the password input, we use the `crypt` function in PostgreSQL's [pgcrypto](https://www.postgresql.org/docs/8.3/pgcrypto.html) module to create a hash. If you read through the [article on password hashing](https://security.blogoverflow.com/2013/09/about-secure-password-hashing/) that was linked earlier, you may be interested to know that we have specified bcrypt as our hashing algorithm.

Once we have the password hash, we insert it into the database along with the email and the first and last name. Provided that the email is not associated with an existing user, the new user should be successfully created, and the user_id returned to the path handler so that the new user can be logged in.

Now that we have written our path handlers and our proc, try creating a new user. It should fail, and if you check your logs you will find a long and somewhat unhelpful error, which begins with something along the lines of:

`App:Error: can't read "column": no such variable.`

To fix this, we must return to our database and make some further changes. You may recall that in the [Validation against the data model tutorial](tutorial-4-validation.md), you ran the following code:

```sql
ALTER TABLE form
  ADD COLUMN first_name plain_string,
  ADD COLUMN last_name plain_string;
```

If it was not entirely clear, then please understand that when the qcode-tcl library automatically validates user input against the data model, it looks in the database to find a matching column to check it against. When we were only adding entries this never presented any difficulties, as every piece of data we submitted corresponded with a column in the entries table. In this case, however, we must submit inputs called "password" and "confirm_password" in our form, neither of which are present in the users tables, and as a result we receive this error.

To correct it, we will add columns named "password" and "confirm_password" to the form table so that, even though we will not actually be storing it in the database, there still is a column for the library to compare our password input to. Run the following command in psql:

```sql
ALTER TABLE form
  ADD COLUMN password plain_string,
  ADD COLUMN confirm_password plain_string;
```

Restart naviserver and refresh the form page, and try creating your user again. This time, you should see "Not found" - this means we have successfully created our new user (check your users table to confirm this) and been redirected to our new user's page, which does not yet have a path handler.

Remember this error and how it is caused (and corrected), because it is likely you will encounter it again, and if you have forgotten what it means you will probably find the error message quite unhelpful.

## Viewing and listing users

Now that we can create users and be redirected to their user page, we should add its path handler:

```tcl
register GET /users/:user_id {user_id} {
    #| View a user
    return [user_get $user_id]
}
```

Let us also add the `user_get` proc to `user.tcl`:

```tcl
proc user_get {user_id} {
    #| Return html summary for this user
    set html ""
    append html [imports_helper]    
    
    db_0or1row {
	select
	firstname,
	surname,
	email
	from
	users
	where user_id=:user_id
	and user_state = 'ACTIVE'
	and user_id != -1
    } {
	append html [h p "User not found."]
    } {
	append html [h h1 "$firstname $surname"]
	append html [h p $email]
	append html [h br]
	
	set entries ""
        db_foreach {
	    select
	    entry_id,
	    entry_title 
	    from entries
	    where entry_author=:user_id
	    order by entry_id asc
	} {
	    append entries [h a href "http://localhost/entries/$entry_id" $entry_title]
	    append entries [h br]
	}

	if {$entries == ""} {
	    append html [h p "This user doesn't seem to have posted any entries."]
	} else {
	    append html [h p "Blogs by this user:"]
	    append html $entries
	}
    }
    return $html
}
```

After appending our imports, we take the user_id in the URL, and retrieve that user's name and email using [`db_0or1row`](https://github.com/qcode-software/qcode-tcl/blob/add966295d72fc33db98b5d2845430862950608a/doc/procs/db_0or1row.md) - note that we include restrictions in our query to exclude any deactivated users, as well as the anonymous user. If the user associated with the id in the URL is deactivated, anonymous, or just not in the database, the content of the page will simply be a message saying that the user was not found.

Otherwise, we will display the user's names and email address. We then check the database for any entries posted by the user and display a list of links to them. If there are no entries posted by the user, we instead display a message saying so.

We will more functionality to this page later, but this will do for now. It will be helpful to have an index page for our users, so add the following pieces of code to their appropriate files:

```tcl
register GET /users {} {
    #| List all users
    return [users_index]
}

proc users_index {} {
    #| Return html report listing links to view each user
    set html ""
    append html [imports_helper]     
    append html [h h1 "All users"]
    append html [h br]
    db_foreach {
	select
	user_id,
	firstname,
	surname
	from users
	where user_id != -1
	and user_state = 'ACTIVE'
	order by user_id asc
    } {
	append html [h a href "http://localhost/users/$user_id" "$firstname $surname"]
	append html [h br]
    }
    return $html
}
```

Note that we have again included a restriction in our SQL query to exclude deactivated users and the anonymous user from the results, so that they are not listed incorrectly on our index page.
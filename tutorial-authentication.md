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

It is also worth taking note of the anonymous user. Run `select * from users;` to see the current collection of users. There should only be one - an anonymous user with a user_id of -1. When a user is not logged in, they will be treated as the anonymous user, and any other table that references a user_id - for example, the sesssion table - will use -1. It is important to treat this special user carefully - for example, we must make sure it cannot be deleted or modified, we must avoid listing it in an index with the other users, and we must ensure anonymous users do not have the same control over anonymous entries that a user has over that user's entries.

Though most of the work has been done for us, there are still some changes we should make to our database before moving on. First, we should change our email column so that each row must be unique - it will not do for us to allow multiple accounts to be made under the same email address. Run the following command in psql:

```sql
ALTER TABLE users ADD UNIQUE (email);
```

We will also want to change the entries table to include an author column so that we have a record of which entries were posted by which users. Run the following command in psql:

```sql
ALTER TABLE entries ADD COLUMN entry_author INT REFERENCES users(user_id) DEFAULT -1;
```

From now on, whenever a user adds a new entry, their user_id will be recorded with it. If there is no user logged in, it will default to the anonymous user_id, -1 - in fact, if you check the entries table you should see that all the entries we added before adding this column have had their entry_author field helpfully filled in with the default value.

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
register GET /entries/new {} {
    #| Form for submitting new blog entry
    set html ""
    append html [imports_helper]
    append html [user_status]
    set form ""
    append form [h label "Blog Title:"]
    append form [h br]
    append form [h input type text name entry_title]
    append form [h br]
    append form [h label "Blog Content:"]
    append form [h br]
    append form [h textarea name entry_content style "width: 400px; height: 120px;"]
    append form [h br]
    append form [h input type submit name submit value Submit]
    append form [h br]
    append form [h br]
    
    append html [qc::form method POST action /entries id "entry-form" $form]
    append html [h a href "http://localhost/entries" "Return to index"]
    append html [validation_helper "entry-form"]
    return $html
}


register POST /entries {entry_title entry_content} {
    #| Create a new blog entry
    set entry_id [entry_create $entry_title $entry_content]
    qc::response action redirect [qc::url "/entries/$entry_id"]    
}

register GET /entries/:entry_id {entry_id} {
    #| View an entry
    return [entry_get $entry_id]
}

register GET /entries {} {
    #| List all entries
    return [entries_index]
}

register GET /entries/:entry_id/edit {entry_id} {
    #| Form for editing a blog entry
    db_1row {
        select
	entry_title,
	entry_content
	from
	entries
	where entry_id=:entry_id
    }
    set html ""
    append html [imports_helper]
    append html [user_status]    
    set form ""
    append form [h label "Blog Title:"]
    append form [h input type text name entry_title value $entry_title]
    append form [h br]
    append form [h label "Blog Content:"]
    append form [h br]
    append form [h textarea name entry_content style "width: 400px; height: 120px;" $entry_content]
    append form [h br]
    append form [h input type hidden name _method value PUT]
    append form [h input type submit name submit value Update]
    append form [h br]
    append form [h br]
    
    append html [qc::form id "update-form" method POST action "/entries/$entry_id" $form]
    append form [h a href "http://localhost/entries" "Return to index"]
    append html [validation_helper "update-form"]   
    return $html
}

register PUT /entries/:entry_id {entry_id entry_title entry_content} {
    #| Update an entry
    entry_update $entry_id $entry_title $entry_content
    qc::response action redirect [qc::url "/entries/$entry_id"]
}

register DELETE /entries/:entry_id {entry_id} {
    #| Delete an entry
    entry_delete $entry_id
    ns_returnredirect [qc::url "/entries"]
}


register GET /users/new {} {
    #| Form for signing up as new user
    set html ""
    append html [imports_helper]
    append html [user_status]
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



register POST /users {firstname surname email password confirm_password} {
    #| Create a new user
    set user_id [user_create $firstname $surname $email $password $confirm_password]
    set session_id [session_new $user_id]
    cookie_set session_id $session_id
    cookie_set authenticity_token [session_authenticity_token $session_id] http_only false    
    qc::response action redirect [qc::url "/users/$user_id"]  
}

register GET /users/:user_id {user_id} {
    #| View a user
    return [user_get $user_id]
}

register GET /users {} {
    #| List all users
    return [users_index]
}

register GET /users/:user_id/edit {user_id} {
    #| Form for editing a user's names/email
    db_1row {
        select
	firstname,
	surname,
	email
	from
	users
	where user_id = :user_id
	and user_id != -1
	and user_state = 'ACTIVE'
    }
    set html ""
    append html [imports_helper]
    append html [user_status]
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]
    if {$session_user_id != $user_id} {
	append html [h p "You cannot edit this user."]
    } else {
	set form ""
	append form [h label "First Name:"]
	append form [h br]
	append form [h input type text name firstname value $firstname]
	append form [h br]
	append form [h label "Last Name:"]
	append form [h br]
	append form [h input type text name surname value $surname]
	append form [h br]
	append form [h label "Email Address:"]
	append form [h br]
	append form [h input type text name email value $email]
	append form [h br]    
	append form [h br]
	append form [h input type submit name submit value Update]

	append html [qc::form id "update-user-form" method PUT action "/users/$user_id" $form]
	append html [validation_helper "update-user-form"]
    }
    return $html        
}

register PUT /users/:user_id {user_id firstname surname email} {
    #| Update a user's names/email
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]
    if {$session_user_id == $user_id} {
	user_update $user_id $firstname $surname $email
    }
    qc::response action redirect [url "/users/$user_id"]
}

register GET /users/:user_id/password/edit {user_id} {
    #| Form for updating a user's password
    set html ""
    append html [imports_helper]
    append html [user_status]
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]
    if {$session_user_id != $user_id} {
	append html [h p "You cannot edit this user."]
    } else {
	set form ""
	append form [h label "Enter Current Password:"]
	append form [h br]
	append form [h input type password name password]
	append form [h br]
	append form [h label "Enter New Password:"]
	append form [h br]
	append form [h input type password name new_password]
	append form [h br]
	append form [h label "Repeat New Password:"]
	append form [h br]
	append form [h input type password name confirm_new_password]
	append form [h br]    
	append form [h br]
	append form [h input type submit name submit value Update]

	append html [qc::form id "update-password-form" method PUT action "/users/$user_id/password" $form]
	append html [validation_helper "update-password-form"]
    }
    return $html 
}

register PUT /users/:user_id/password {user_id password new_password confirm_new_password} {
    #| Update a user's password
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]
    if {$session_user_id == $user_id} {
	user_password_update $user_id $password $new_password $confirm_new_password
    }
    qc::response action redirect [url "/users/$user_id"]    
}


register DELETE /users/:user_id {user_id} {
    #| Delete a user
    user_delete $user_id
    set session_id [session_new -1]
    cookie_set session_id $session_id
    cookie_set authenticity_token [session_authenticity_token $session_id] http_only false
    qc::response action redirect [qc::url "/users"] 
}

register GET /users/login {} {
    #| Form for logging in as a user
    set html ""
    append html [imports_helper]
    append html [user_status]
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]

    if {$session_user_id != -1} {
	append html [h p "You are already logged in."]
    } else {
	set form ""
	append form [h br]
	append form [h label "Enter Email:"]
	append form [h br]
	append form [h input type text name email]
	append form [h br]
	append form [h label "Enter Password:"]
	append form [h br]
	append form [h input type password name password]
	append form [h br]
	append form [h br]    
	append form [h input type submit name submit value Submit]

	append html [qc::form id "login-form" method POST action /users/login $form]
	append html [validation_helper "login-form"]
    }
    return $html 
}

register POST /users/login {users.email form.password} {
    #| Log a user in
    set user_id [user_login $email $password]
    if { $user_id } {
	set session_id [session_new $user_id]
	cookie_set session_id $session_id
	cookie_set authenticity_token [session_authenticity_token $session_id] http_only false
	qc::response action redirect [qc::url "/users/$user_id"] 
    } else {
	ns_log error "Invalid email or password."
    }
}

register POST /users/logout {} {
    #| Log a user out
    set session_id [session_new -1]
    cookie_set session_id $session_id
    cookie_set authenticity_token [session_authenticity_token $session_id] http_only false
    qc::response action redirect [qc::url "/users"] 
}




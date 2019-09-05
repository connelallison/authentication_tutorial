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

proc user_get {user_id} {
    #| Return html summary for this user
    set html ""
    append html [imports_helper]    
    append html [user_status]      
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]
    
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

	append html [h br]
	if {($user_id == $session_user_id) && ($session_user_id != -1)} {
	    append html [h a href "http://localhost/users/$user_id/edit" "Edit user details"]
	    append html [h br]
	    append html [h a href "http://localhost/users/$user_id/password/edit" "Change password"]
	    append html [form id "delete-user" method DELETE action /users/$user_id \
			 [h input type submit name submit value "Delete user"]]
	    append html [validation_helper "delete-user"]
	}
    }
    return $html
    
}

proc users_index {} {
    #| Return html report listing links to view each user
    set html ""
    append html [imports_helper]     
    append html [user_status]    
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


proc user_update {user_id firstname surname email} {
    #| Update a user's names and email
    db_dml "update users \
            set [sql_set firstname surname email] \
            where user_id=:user_id"
    return $user_id
}

proc user_password_update {user_id password new_password confirm_new_password} {
    #| Update a user's password
    if {$new_password ne $confirm_new_password} {
	error "Your passwords do not match." {} USER
    }
    if {$password == $new_password} {
	error "Your new password must be different from your old one." {} USER
    }
    
    password_complexity_check $new_password min 4 max 20 minclasses 1

    db_1row {select crypt(:new_password, gen_salt('bf', 7)) as password_hash}

    db_dml "update users \
            set [sql_set password_hash] \
            where user_id = :user_id
            and user_id != -1
	    and user_state = 'ACTIVE'
	    and password_hash = crypt(:password, password_hash)"
}


proc user_delete {user_id} {
    #| Delete a user
    set session_id [session_id]
    set session_user_id [session_user_id $session_id]
    if {$user_id != $session_user_id} {
	return error "Cannot delete other users"
    } else {
	db_dml "update users \
                set user_state = 'DISABLED' \
                where user_id = :user_id 
                and user_id != -1"
	db_dml "delete from entries \
                where entry_author = :user_id"
    }
}

proc user_login {email password} {
    #| Log a user in
    db_0or1row {
	select
	user_id
	from
	users
	where email = :email
	and user_id != -1
	and user_state = 'ACTIVE'
	and password_hash = crypt(:password, password_hash)
    } {
	return 0
    } {
	return $user_id
    }
}

proc user_status {} {
    #| Display either links to login/sign up or the current user and a logout button 
    set session_id [session_id]
    set user_id [session_user_id $session_id]
    set status ""
    if {$user_id == -1} {
	append status [h p "[h a href "http://localhost/users/login" "Log in"] or
		       [h a href "http://localhost/users/new" "sign up"]"]
    } else {
	db_1row {
	    select
	    firstname,
	    surname
	    from
	    users
	    where user_id=:user_id
	}
	append status [form method POST id logout action "http://localhost/users/logout" "
			   [h input type submit name logout value "Log out"]
                           [h label "Logged in as [h a href "http://localhost/users/$user_id" \
						       "$firstname $surname"]"] 
                      "]
	append status [validation_helper logout]
    }
    append status [h p "[h a href "http://localhost/users" "All Users"] / [h \
                           a href "http://localhost/entries" "All Entries"] / [h \
                           a href "http://localhost/entries/new" "Submit a blog"]
                       "]    
    return $status
}


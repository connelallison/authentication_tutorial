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

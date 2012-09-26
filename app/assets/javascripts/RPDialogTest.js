// Functions for testing dialog running

// Debugging aid, which places JSON response into a source span
function presentResponse(responseData) {
	var span = $('span.source')
	if($(span).length > 0) {
		$(span).html("");
		for(var propertyName in responseData) {
			var value = responseData[propertyName];
			$(span).append($('<strong>').text(propertyName+" : "));
			if(propertyName == "code") {
				$(span).append(
					$('<pre>').text(value)
				)
			} else {
				$(span).
					append($('<i>').text(value || "null")).
					append('<br>');
			}
		}
		return true;
	} else {
		return false;
	}
}

// prepare the form when the DOM is ready 
$(document).ready(function() { 
    var options = { 
        beforeSubmit:  showRequest,  // pre-submit callback 
 
        // other available options: 
        //url:       url         // override for form's 'action' attribute 
        //type:      type        // 'get' or 'post', override for form's 'method' attribute 
        //dataType:  null        // 'xml', 'script', or 'json' (expected server response type) 
        //clearForm: true        // clear all form fields after successful submit 
        //resetForm: true        // reset the form after successful submit 
 
        // $.ajax options can be used here too, for example: 
        //timeout:   3000 
    }; 
 
    // bind to the form's submit event 
    $('#TestDialog').submit(function() { 
        // inside event callbacks 'this' is the DOM element so we first 
        // wrap it in a jQuery object and then invoke ajaxSubmit 
        $(this).ajaxSubmit(options); 
 
        // !!! Important !!! 
        // always return false to prevent standard browser submit and page navigation 
        return false; 
    }); 
}); 
 
// pre-submit callback 
function showRequest(formData, jqForm, options) { 
    // formData is an array; here we use $.param to convert it to a string to display it 
    // but the form plugin does this for you automatically when it submits the data 
    var fields = {};
    var queryString = $.param(formData); 
    formData.forEach( function(elmt) {
	   if(elmt.name == "url") {
		  fields.url = elmt.value
	   } else if(elmt.name == "area") {
		  fields.area = elmt.value
	   } else if(elmt.name == "mode") {
		  fields.mode = elmt.value
	   } else if(elmt.name == "format") {
		  fields.format = elmt.value
	   }
	})
	if(fields.format == "JSON" && fields.mode == "page") {
		alert("Can't get full pages with JSON")
	} else {
	  responder =  (fields.url.match(/collect/)) ? collectRecipeCallback : null;
      if(fields.format == "HTML") {
	    recipePowerGetAndRunHTML(fields.url, fields.mode, fields.area);
	  } else {
		recipePowerGetAndRunJSON(fields.url, fields.mode, fields.area);
	  }
	}
 
    // jqForm is a jQuery object encapsulating the form element.  To access the 
    // DOM element for the form do this: 
    // var formElement = jqForm[0]; 
 
    // here we could return false to prevent the form from being submitted; 
    // returning anything other than false will allow the form submit to continue 
    return false; 
} 

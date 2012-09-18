
/* Take an HTML stream and run a dialog from it. Assumptions:
  1) The body is a div element of class 'dialog'. (It will work if the 'div.dialog'
	is embedded within the HTML, but it won't clean up properly.)
  2) There is styling on the element that will determine the width of the dialog
  3) [optional] The 'div.dialog' has a 'title' attribute containing the title string
  4) The submit action returns a json structure that the digestion function understands
  5) The dialog will be run modally unless there is a 'at_top' class or 'at_left' class
	on the 'div.dialog' element.
  6) While not required, it is conventional that an 'Onload' function be defined for the 
	dialog to set up various response functions.
*/

/* Utility for setting the function called when closing the dialog */
function dialogCallback( fcn ) {
  if(fcn == undefined) {
	return $('div.dialog').data("callback");
  } else {
	$('div.dialog').data("callback", fcn);
  }
}

function dialogResult( obj ) {
  if(obj == undefined) {
	return $('div.dialog').data("dialog_result");
  } else {
	$('div.dialog').data("dialog_result", obj);
  }
}

// Javascript to replace the current page with the error (or any other full) page
function doError() {
	return $('#container').data("error_page");
}

/* Handle the error result from either a forms submission or a request of the server */
function processErrorResult(html) {
	// Hopefully the responseText is HTML...
	var re = new RegExp(/^<div.*\bclass\b\s*=\s*\".*\bdialog\b/);
	/* Testers for the re
	var match1 = "<div class=\"dialog\"".match(re);
	var match2 = "<div class =\"dialog\"".match(re);
	var match3 = "<div class= \"dialog\"".match(re);
	var match4 = "<div class=\"rcpEdit dialog\"".match(re);
	var match5 = "<div class=\"rcpEditdialog\"".match(re);
	*/
	debugger;
	if(html.match(/<!DOCTYPE/)) { // A whole page
		dialogResult( { page: html } );
	} else if(html.match(re)) { // or a dialog
		dialogResult( { dialog: html } );
	}	
}

/* Handle successful return of the JSON request */
function processSuccess(responseData) {
  debugger;
  if(responseData.page || responseData.dialog) {
	// We got a result we can handle; stash it in the dialog result and return false
	// XXX If it's a full page, check for the presence of a dialog ('div.dialog'); if 
	// present, extract and run it. if not, just do normal forms processing after return
	// Instead of falling to default form handling, record the data in 'div.dialog'
	dialogResult( responseData );
    return false;
  }
  return true;
}

/* Process the result of hitting the server with a general request, whether from a forms
  submission or a free-standing request. 
  'data' is an object, either coming directly from a JSON request or indirectly by catching
   HTML that came in on failure of a JSON request (in which case the object has a 'page' or
   a 'dialog' attribute, depending on whether the HTML was a full page or a dialog fragment). */
function processResponse(data) {
	debugger;
	if(data != null) {
		// Process the data as returned
		if(data.page) { // Full page: open it
			$('#container').data("error_page", data.page );
			location.replace('javascript:doError()');
		} else if(data.dialog) {
			runDialog(data.dialog);					
		}
	}	
}

// Run a dialog from a body of HTML, which should be a div with 'dialog' class as outlined above.
function runDialog(body) {
	$("#container").append(body);
	$("input.cancel").click( function(event) {
		$('div.dialog').dialog("close");
		event.preventDefault();
	} );
	// Any forms get submitted and their results handled appropriately. NB: the submission
	// must be synchronous because we have to decide AFTER the results return whether to handle
	// the form result normally.
	$('form').submit( function(eventdata) { // Supports multiple forms in dialog
		var context = this;
		var process_result_normally = true;
		debugger;
		/* To sort out errors from subsequent dialogs, we submit the form asynchronously
		   and use the result to determine whether to do normal forms processing. */
		$(context).ajaxSubmit( {
			async: false,
			dataType: "json",
			error: function(jqXHR, textStatus, errorThrown) {
				processErrorResult(jqXHR.responseText);
			    $('div.dialog').dialog("close");
			    process_result_normally = false;
			},
			success: function (responseData, statusText, xhr, form) {
				process_result_normally = processSuccess(responseData);
				$('div.dialog').dialog("close");
			}
		});
		return process_result_normally;
	})
	// Dialogs are modal by default, unless the classes 'at_top' or 'at_left' are asserted
	var isTop = $('div.dialog').hasClass("at_top");
	var isLeft = $('div.dialog').hasClass("at_left");
	var options = {
		position: ['left', 'top'],
		close: function() {
			// It is expected that any dialogs have placed the response data object into the 'div.dialog'
			var returned_data = dialogResult();
			debugger;
			var callback = dialogCallback();
			if(callback) {
				callback(returned_data);
			}
			$('div.dialog').dialog("destroy");
			$('div.dialog').remove();
			// It is expected that any dialogs have placed the response data object into the 'div.dialog'
			processResponse(returned_data);
		}
	}
	// XXX These should be in CSS
	if(isTop) {
		options.width = '100%';
		options.height = '150px';
	} else if (isLeft) {
		options.height = 'auto';
		options.width = '250px';
	} else {
		options.modal = true;
		options.width = 'auto';
		options.height = 'auto';
		options.position = "center";
	}
	$("div.dialog").dialog( options );				
}

/* Submit a request to the server for interactive HTML. It's meant to be JSON specifying how 
   to handle it, but if the controller doesn't produce JSON (or if the request gets redirected
   to a controller which doesn't), the request may produce generic HTML, failing with an error 
   but still providing the HTML. The HTML may be
   either a dialog (in the form of a div with class 'dialog') or a full page. In turn, the full
   page may have a dialog embedded in it (again, as a div.dialog). If a dialog, embedded or not,
   we run it on the current page. If a full page without a dialog, we throw up our 
   hands and just load the page.

   If the request DOES return JSON, there are several possibilities:
   -- any "page" attribute is treated as HTML, exactly as above
   -- any "dialog" attribute is run on this page. The div containing the dialog may have classes
			'at_left' or 'at_top', in which case they are run non-modally inside an iframe. 
			Otherwise, run the dialog modally.
   -- any "replacements" attribute is assumed to be a series of selector-value pairs, where the 
		selectors stipulate elements to be replaced with the corresponding value
   -- any "notification" attribute is used as the text for a notifier of success
*/

// This function can be tied to a link with only a URL to a controller for generating a dialog.
// We will get the div and run the associated dialog.
function applyForInteraction(querystr) {
	$.ajax( {
		type: "GET",
		dataType: "json",
		url: querystr,
		error: function(jqXHR, textStatus, errorThrown) {
			processErrorResult(jqXHR.responseText);
		},
		success: function (responseData, statusText, xhr) {
			processResponse(responseData);
		}
	});
}


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

function recipePowerGetAndRunHTML(request, how, area) {
	if(area) { // No area specified => up to the controller (usually defaults to 'page')
		request += "?area="+area
	}
	$('span.query').text(request);
	var xmlhttp;
	// Send the request using minimal Javascript
	if (window.XMLHttpRequest) { xmlhttp=new XMLHttpRequest(); }
	else {
	  try { xmlhttp = new ActiveXObject("Msxml2.XMLHTTP"); }
	  catch (e) {
		try { xmlhttp = new ActiveXObject("Microsoft.XMLHTTP"); }
		catch (e) { xmlhttp = null; }
	  }
	}
	if(xmlhttp != null) {
	  xmlhttp.onreadystatechange=function() {
	    if (xmlhttp.readyState==4 && xmlhttp.status==200) {
		  // Now we have code, possibly required for jQuery and certainly 
		  // required for any of our javascript. Ensure the code is loaded.
		  if(xmlhttp.responseText) {
			  (typeof presentResponse === 'function' && presentResponse({code: xmlhttp.responseText})) || 
			  runAppropriately(xmlhttp.responseText, how, area)
		  }
	    }
	  }
	  xmlhttp.open("GET", request, true);
	  xmlhttp.setRequestHeader("Accept", "text/html" );
	  xmlhttp.send();		
	}
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
			'at_left' or 'at_top', in which case they are run non-modally inside a div
			Otherwise, run the dialog modally.
   -- any "replacements" attribute is assumed to be a series of selector-value pairs, where the 
		selectors stipulate elements to be replaced with the corresponding value
   -- any "notification" attribute is used as the text for a notifier of success
*/

// This function can be tied to a link with only a URL to a controller for generating a dialog.
// We will get the div and run the associated dialog.
function recipePowerGetAndRunJSON(request, how, area) {
	if(area) {
		request += "?area="+area
	}
	$('span.query').text(request);
	$.ajax( {
		type: "GET",
		dataType: "json",
		url: request,
		error: function(jqXHR, textStatus, errorThrown) {
			$('span.source').text(jqXHR.responseText);
			postErrorResult(jqXHR.responseText);
		},
		success: function (responseData, statusText, xhr) {
			(typeof presentResponse === 'function' && presentResponse(responseData)) || 
			runAppropriately(responseData.code, how, responseData.area);
		}
	});
}

function runAppropriately(code, how, area) {
  if(how == "page") {
    runPage(code);
  } else if(how == "modeless") {
	injectDialog(code, area);
  } else { // at_top and at_left run modelessly
	runModalDialog(code, area);					
  }
}

// Debugging aid: if there is a 'div.results' element we maintain a span of class 'query' for recording the query. Maybe.
// This function toggles that.
function toggleResults() {
  if($('span.query').length > 0) {
	$('div.results').html("");
  } else {
    $('div.results').html("<hr><h3>Query</h3><span class='query'></span><br><hr><h3>Result</h3><span class='source'></span><br><hr>");
  }
}

/* Utility for setting and getting the function called when closing the dialog */
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
	return $('#container').data("pending_page");
}

/* Handle the error result from either a forms submission or a request of the server */
function postErrorResult( html ) {
	dialogResult( html ? { code: html } : null );
}

/* Handle successful return of the JSON request */
function postSuccess(jsonResponse) {
  if(jsonResponse.page || jsonResponse.dialog) {
	// We got a result we can handle; stash it in the dialog result and return false
	// XXX If it's a full page, check for the presence of a dialog ('div.dialog'); if 
	// present, extract and run it. if not, just do normal forms processing after return
	// Instead of falling to default form handling, record the data in 'div.dialog'
	dialogResult( jsonResponse );
    return false;
  }
  return true;
}

function runPage(html) {
	if(html) {
		$('#container').data("pending_page", html );
		location.replace('javascript:doError()');		
	}
}

// Run a dialog from a body of HTML, which should be a div with 'dialog' class as outlined above.
function runModalDialog(body, area) {
	// Parse HTML, extract 'div.dialog' element (as nec.), then append to container
	var dlog = injectDialog(body, area); 
	$("input.cancel").click( function(event) {
		$('div.dialog').dialog("close");
		event.preventDefault();
	});
	// Any forms get submitted and their results handled appropriately. NB: the submission
	// must be synchronous because we have to decide AFTER the results return whether to handle
	// the form result normally.
	$('form').submit( function(eventdata) { // Supports multiple forms in dialog
		var context = this;
		var process_result_normally = true;
		/* To sort out errors from subsequent dialogs, we submit the form asynchronously
		   and use the result to determine whether to do normal forms processing. */
		$(context).ajaxSubmit( {
			async: false,
			dataType: "json",
			error: function(jqXHR, textStatus, errorThrown) {
				postErrorResult(jqXHR.responseText);
			    $('div.dialog').dialog("close");
			    process_result_normally = false;
			},
			success: function (responseData, statusText, xhr, form) {
				process_result_normally = postSuccess(responseData);
				$('div.dialog').dialog("close");
			}
		});
		return process_result_normally;
	})
	// Dialogs are modal by default, unless the classes 'at_top' or 'at_left' are asserted
	var options = {
		modal: true,
		width: 'auto',
		position: ['left', 'top'],
		close: function() {
			// It is expected that any dialogs have placed the response data object into the 'div.dialog'
			var returnedData = dialogResult();
			var callback = dialogCallback();
			if(callback) {
				callback(returnedData);
			}
			$('div.dialog').dialog("destroy");
			// Remove the first child of 'body', which is our dialog (if any)
			withdrawDialog(); // $('div.dialog').remove();
			if(returnedData) {
				runAppropriately(returnedData.code, "modal", returnedData.area)
			}
		}
	}
	if((area == "floating") || (area == "page")) {
		options.position = "center";
	}
	$("div.dialog").dialog( options );				
}

// Inject the dialog on the current document, using the given HTML
function injectDialog(code, area) {
	// First, remove any lingering style or script elements on the page
	$('link.RecipePowerInjectedStyle').remove();
	// Inject our styles
	$('<link href="/assets/foreign/dialog.css?body=1" media="screen" rel="stylesheet" type="text/css" id="RecipePowerInjectedStyle"/>').appendTo('head');
	// Parse the code, creating an html element outside the DOM, then pulling the
	// 'div.dialog' element from that.
	var dlog = $('div.dialog', $('<html></html>').html(code));
	debugger;
	if(!(area && $(dlog).hasClass(area)) ) {
		// If the area isn't specified anywhere, 'floating' is the default
		area = "floating"
		// For one reason or another, the dialog is laid out for an area different from that requested
		var positions = ["at_left", "at_top", "floating", "page"];
	    for(var i = 0, len = positions.length; i < len; ++i) {
			if($(dlog).hasClass(positions[i])) {
				area = positions[i];
			}
	    }
	}
	if($('#RecipePowerInjectedEncapsulation').length == 0) { // XXX depends on jQuery
	  // Need to encapsulate existing body
	  var theFrame = $("<div id='RecipePowerInjectedEncapsulation'></div>");
	  $("body").children()
	    // Put them into their own div
		.wrapAll(theFrame);
	} 
	// Any old dialog will be either a predecessor or successor of the encapsulation
	var odlog = $('#RecipePowerInjectedEncapsulation').prev().add(
				$('#RecipePowerInjectedEncapsulation').next());
	if($(odlog).length > 0) {
	  // Page has existing dialog, either before or after injection => Remove it
	  // Clean up javascript namespace
	  $(odlog).remove();
	}
	// Now the page is ready to receive the code, prepended to the page
	// We extract the dialog div from what may be a whole page
	// Ensure that all scripts are loaded
	// Run after-load functions
	if((area == "at_left") || (area == "at_top")) {
		$("body").prepend($(dlog)); 
	} else {
		$("body").append($(dlog)); 
	}
	dlog = $('div.dialog'); // Now the dialog is in the DOM
	// We get and execute the onload function for the dialog
	var onload = $('div.dialog').attr("onload");
	debugger;
	if (onload && (typeof window[onload] === 'function')) {
		window[onload]();
	}
	if(area == "at_left") {
	    $('#RecipePowerInjectedEncapsulation').css("marginLeft", $(dlog).css("width"))
	}
	return dlog;
}

// Remove the dialog and injected code
function withdrawDialog() {
	var odlog = $('#RecipePowerInjectedEncapsulation').prev().add(
				$('#RecipePowerInjectedEncapsulation').next());
	$(odlog).dialog("destroy");
	// Remove the first child of 'body', which is our dialog (if any)
	$(odlog).remove();
	/* Unwrap the page contents from their encapsulation */
	$('#RecipePowerInjectedEncapsulation').children().unwrap();
	/* Remove any injected styles from the head */
	$('link.RecipePowerInjectedStyle').remove();
}

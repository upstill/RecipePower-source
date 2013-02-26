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
function recipePowerGetAndRunJSON(request, how, area ) {
	how = how || "modal"
	area = area || "floating"
	request += (request.match(/\?/) ? "&" : "?") + "area=" + area
	
	$('span.query').text(request);
	$.ajax( {
		type: "GET",
		dataType: "json",
		url: request,
		error: function(jqXHR, textStatus, errorThrown) {
			$('span.source').text(jqXHR.responseText);
			var responseData = postError(jqXHR);
			runResponse(responseData);
		},
		success: function (responseData, statusText, xhr) {
			responseData.how = responseData.how || how;
			postSuccess(responseData); // Don't activate any response functions since we're just opening the dialog
			runResponse(responseData);
		}
	});
}

// onclick handler to fire a request at the server and appropriately handle the response
function recipePowerRunRequest(request) {
	var target = this.event.currentTarget;
	var attribs = target.attributes;
	var method = attribs.method.value;
	var confirm = attribs.confirm.value;
	bootbox.confirm(confirm, function(result) {
		if(result)
			recipePowerSubmit(request, method);
	});
}

function recipePowerSubmit( request, method, assumptions ) {
	assumptions = assumptions || {} // No assumptions if absent
	$.ajax( {
		type: method,
		dataType: "json",
		url: request,
		error: function(jqXHR, textStatus, errorThrown) {
			$('span.source').text(jqXHR.responseText);
			var responseData = postError(jqXHR);
			responseData.how = responseData.how || assumptions.how;
			runResponse(responseData);
		},
		success: function (responseData, statusText, xhr) {
			// Pass any assumptions into the response data
			responseData.how = responseData.how || assumptions.how;
			postSuccess(responseData); 
			runResponse(responseData);
		}
	});
	
}

// Process response from a request. This will be an object supplied by a JSON request,
// which may include code to be presented along with fields (how and area) telling how
// to present it. The data may also consist of only 'code' if it results from an HTML request
function runResponse(responseData) {
	// Wrapped in 'presentResponse', in the case where we're only presenting the results of the request
	var sorted = false;
	if(responseData) { // && !(typeof presentResponse === 'function' && presentResponse(responseData)))
	  if (replacements = responseData.replacements) {
			var i = 0;
			while(i < replacements.length) {
				replacement = replacements[i];
				$(replacement[0]).replaceWith(replacement[1]);
				i++;
			}
		}
		if(newdlog = responseData.dlog) {
			var dlog = $('div.dialog.modal')[0]
			if(dlog) {
				dlog.parentNode.insertBefore(newdlog, dlog);
				newdlog = dlog.previousSibling;
				closeModal(dlog);
			} else {
				// Add the new dialog at the end of the page body
				newdlog = document.getElementsByTagName("body")[0].appendChild(newdlog);
			}
			recipePowerRunBootstrap(newdlog);
			sorted = true;
		}
		postNotifications(responseData.notifications);
		if(page = responseData.page) {
			document.open();
			document.write(page);
			document.close;
			sorted = true;
		}	
		if(code = responseData.code) {
			var placed = false;
			if(!responseData.how) {
				if(responseData.area == "floating") 
					responseData.how = "modal"
				else if ((responseData.area == "at_left") || (responseData.area == "at_top"))
					responseData.how = "modeless"
			}
			
			if(responseData.how == "modeless")
				placed = injectDialog(code, responseData.area, true);
			else if(responseData.how == "modal") // at_top and at_left run modelessly
				placed = runModalDialog(code, responseData.area);	
			else if(responseData.how == "bootstrap") 
			  placed = recipePowerRunBootstrap(injectDialog(code, responseData.area, false));				

			if (!placed) { // Force the page to be displayed. XXX Does nothing to the address bar
				// $('#container').data("pending_page", code ); // Stash for doError function
				// window.location.replace('javascript:doError()');	
				document.open();
				document.write(code);
				document.close;
			}
			sorted = true;
		}
	} 
	return sorted;
}

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

function recipePowerGetAndRunHTML(request, params ) {
	// Serialize the request
  var how = "modeless"
  var area = "at_top"
  if(typeof params === 'object') {
		var str = [];
		for(var p in params)
		  str.push(encodeURIComponent(p) + "=" + encodeURIComponent(params[p]));
		request += "?" + str.join("&");
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
	    if (xmlhttp.readyState==4) {
				if(xmlhttp.status==200) {
				  // Now we have code, possibly required for jQuery and certainly 
				  // required for any of our javascript. Ensure the code is loaded.
				  var result = { code: xmlhttp.responseText };
				  if(typeof postSuccess === 'function') 
					  postSuccess( result );
				  result.how = how;
				  result.area = area;
				  if(typeof runResponse === 'function')
					  runResponse( result );
		    }
			}
	  }
	  xmlhttp.open("GET", request, true);
	  xmlhttp.setRequestHeader("Accept", "text/html" );
	  xmlhttp.send();		
	}
}

// Insert any notifications into 'div.notifications-panel'
function postNotifications(nots) {
	if(nots) {
		var i = 0;
		var notsout = "";
		debugger
		while (i < nots.length) {
			not = nots[i];
			var alert_class = nat[0];
			var alert_content = nat[1];
			natsout << "<div class=\"alert alert-" + 
									alert_class + 
									"\"><a class=\"close\" data-dismiss=\"alert\">x</a>" +
		    					alert_content + 
		  						"</div>"
			i = i+1;
		}
		var panel = $('div.notifications-panel')[0]
		if (panel)
			panel.innerHTML = natsout;
	}
}

// Determine either the callback (kind = "Fcn") or the message (kind="Msg")
//  for a given event type from among:
// load
// save
// cancel
// close
// If there's a function for the event in the hooks, call it
// otherwise, if there's a message for the event in the hooks, post it
// otherwise, apply the default event handler 
function dialogOnEvent(what_event, dlog, entity) {
	var hooks = $(entity || dlog).data("hooks");
	var fcn_name = what_event+"Fcn";
	var msg_name = what_event+"Msg";
	if(hooks) {
		if(hooks.hasOwnProperty(msg_name))
			jNotify( hooks[msg_name], { HorizontalPosition: 'center', VerticalPosition: 'top', TimeShown: 1200 } );
		if(hooks.hasOwnProperty(fcn_name)) {
			var fcn = RP.named_function(hooks[fcn_name]);
			return fcn(dlog);
		}
	} else if(RP && RP.dialog)
		return RP.dialog.apply('on'+what_event, dlog);
	return null;
}

// Store the response to a query (including forms submissions)
// in the dialog--if any--for later processing. 
// OR--if obj is undefined--return the stored struct
function dialogResult( dlog, obj ) {
	if(dlog) {
		if(obj == undefined)
			return $(dlog).data("dialog_result");
		else
			$(dlog).data("dialog_result", obj);
	}
}

/* Handle the error result from either a forms submission or a request of the server
  by treating the html as code to be rendered and sticking it in an object attached
  to the dialog, if any. */
function postError( jqXHR, dlog ) {
	// Any error page we get we will <try> to present modally
	var jstruct = {};
	var errtxt;
	if(errtxt = jqXHR.responseText) {
		// See if it's valid JSON
		try
		{
			parsage = JSON && JSON.parse(errtxt) || $.parseJSON(errtxt);
		}
		catch(e)
		{
			// Not valid JSON. Maybe it's a page to go to?
			if (errtxt.match(/^\s*<!DOCTYPE html>/)) {
				var dom = $(errtxt);
			  var newdlog = $('div.dialog', dom);
				if(newdlog[0])
					parsage = { dlog: newdlog[0] }
				else
					parsage = { page: errtxt }
			} else
				// Okay. Assume it's just a string error report
				parsage = { errortext: errtxt };
		}
	}
	result = null;
	// Stash the result in the dialog, if any
	if(dlog != 'undefined') 
		dialogResult( dlog, parsage );

	return parsage;
}

/* Handle successful return of a JSON request by running whatever success function
   obtains, and stashing any resulting code away for invocation after closing the
   dialog, if any. */
function postSuccess(jsonResponse, dlog, entity) {

  // Call processor function named in the response
  var closer;
  if(closer = RP.named_function(jsonResponse.processorFcn) )
		closer(jsonResponse);
		
	// Call the dialog's response function
	if((dlog != undefined) || (entity != undefined))
		dialogOnEvent("save", dlog, entity);
		
  // Stash the result for later processing
  if(dlog != undefined)
		dialogResult( dlog, jsonResponse );
  return false;
}

// Handle forms submission on a dialog (both successful and unsuccessful) by closing
// the dialog either directly (by closing the div, if it's modeless) or indirectly
// (calling the dialog's close method, if it's modal)
function closeDialog(dlog) {
	var returnedData = dialogResult(dlog); // Get the JSON response back again, if any
	if($(dlog).hasClass('ui-dialog-content'))
		closeModeless(dlog);
	else {
	  // Modal dialog
	  closeModal(dlog); 
	  runResponse(returnedData);
	}
}

// Run a dialog from a body of HTML, which should be a div with 'dialog' class as outlined above.
function runModalDialog(body, area) {
	var dlog = injectDialog(body, area, false); 
	// Any forms get submitted and their results handled appropriately. NB: the submission
	// must be synchronous because we have to decide AFTER the results return whether to handle
	// the form result normally.
	if(dlog) {
		// Dialogs are modal by default, unless the classes 'at_top' or 'at_left' are asserted
		var options = {
			modal: true,
			width: dlog.width(), // Barely enclose the dialog with our window
			position: ['left', 'top'],
			close: function() {
				// It is expected that any dialogs have placed the response data object into the dlog object
				var returnedData = dialogResult(dlog);
				// $(dlog).dialog("destroy");
				// Remove the first child of 'body', which is our dialog (if any)
				closeModal(dlog); 
				runResponse(returnedData);
			}
		}
		if((area == "floating") || (area == "page"))
			options.position = "center";
		$(dlog).dialog( options );	
	}
	return dlog;			
}

// Take a Boostrap dialog and run it modally. Trap the 
// form submission event to give us a chance to get JSON data and inject it into the page
// rather than do a full page reload.
function recipePowerRunBootstrap(dlog) {
	if(!$(dlog).hasClass("modal")) // The modality may be hidden if prepared for a page
		$(dlog).addClass("modal");
	$(dlog).removeClass("hide");
	$(dlog).on('shown', function() {
		$('textarea', dlog).focus();
	});
	$(dlog).modal('show');
	// Forms submissions that expect JSON structured data will be handled here:
	// $('form', dlog).filter('[data-type="json"]').submit( dlog, function (eventdata) {
	$('form', dlog).submit( dlog, function (eventdata) {
		var context = this;
		var dlog = eventdata.data; // As stored when the dialog was set up
		var process_result_normally;
		if(process_result_normally = !dialogOnEvent("beforesave", dlog, eventdata.currentTarget)) {
			// Okay to submit
			/* To sort out errors from subsequent dialogs, we submit the form synchronously
			   and use the result to determine whether to do normal forms processing. */
			$(context).ajaxSubmit( {
				async: false,
				dataType: 'json',
				error: function(jqXHR, textStatus, errorThrown) {
					// Try it with HTML
					/*
					$(context).ajaxSubmit( {
						async: false,
						dataType: 'html',
						error: function(jqXHR, textStatus, errorThrown) {
							debugger;
							htmlout = postError(jqXHR, dlog); // Show the error message in the dialog
							// closeDialog(dlog);
							runResponse(htmlout);
							process_result_normally = false;
						},
						success: function (responseData, statusText, xhr, form) {
							process_result_normally = postSuccess(responseData, dlog, form);
							closeDialog(dlog);
						}
					} ); 
					*/
					jsonout = postError(jqXHR, dlog); // Show the error message in the dialog
					process_result_normally = !runResponse(jsonout);
				},
				success: function (responseData, statusText, xhr, form) {
					process_result_normally = postSuccess(responseData, dlog, form);
					eventdata.preventDefault();
					closeDialog(dlog);
				}
			} ); 
		} else {
			closeDialog(dlog);
			eventdata.preventDefault();
		}
		return process_result_normally;		
	});
	return true;
}

// Inject the dialog on the current document, using the given HTML code
function injectDialog(code, area, modeless) {
  var dlog = $('div.dialog', $('<html></html>').html(code));
  if(dlog) {	
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
		// Now the page is ready to receive the code, prepended to the page
		// We extract the dialog div from what may be a whole page
		// Ensure that all scripts are loaded
		// Run after-load functions
		
		$("body").append($(dlog)); 
		var dlog = $("body").children().last(); 
		launchDialog(dlog, area, modeless);
	}
	return dlog;
}

// Set the dialog up to run
function launchDialog(dlog, area, modeless)
{
	// We get and execute the onload function for the dialog
	RP.dialog.apply("onload", dlog);
	// Cancel will remove the dialog and confirm null effect to user
	$('input.cancel', dlog).click( function (event) {
		dialogOnEvent("success", dlog, this); // Run the function or post the message for the cancel button
		if(modeless)
			// Cancel modeless dialog
			closeModeless(dlog);
		else
			// Cancel modal dialog
			closeModal(dlog);
		event.preventDefault();			
	});
	
	// Forms submissions that expect JSON structured data will be handled here:
	$('form', dlog).filter('[data-type="json"]').submit( dlog, function (eventdata) {
		var context = this;
		var dlog = eventdata.data; // As stored when the dialog was set up
		eventdata.preventDefault();
		var process_result_normally;
		if(process_result_normally = !dialogOnEvent("beforesave", dlog, eventdata.currentTarget)) {
			// Okay to submit
			/* To sort out errors from subsequent dialogs, we submit the form synchronously
			   and use the result to determine whether to do normal forms processing. */
			$(context).ajaxSubmit( {
				async: false,
				dataType: 'json',
				error: function(jqXHR, textStatus, errorThrown) {
					postError(jqXHR, dlog);
					closeDialog(dlog);
					process_result_normally = false;
				},
				success: function (responseData, statusText, xhr, form) {
					process_result_normally = postSuccess(responseData, dlog, form);
					closeDialog(dlog);
				}
			} ); 
		} else 
				closeDialog(dlog);
		return process_result_normally;		
	});
	
	// Position dialog according to its area
	if(area == "at_left") {
		$(dlog).css( "position", "fixed" );
		$(dlog).css( "top", "30px" );
		$(dlog).css( "left", "100px" );
	}
}

// Remove the dialog and injected code
function closeModal(dlog) {
	if('.modal-header', dlog)
		$(dlog).modal('hide');
	else
		$(dlog).dialog("destroy"); // If running a jquery dialog 
	// If the dialog has an associated manager, call its onclose function
	if(!dialogOnEvent("close", dlog))
		// Remove the first child of 'body', which is our dialog (if any)
		$(dlog).remove();	
}

function closeModeless(dlog) {
  $(dlog).dialog("close");
	if(!dialogOnEvent("close", dlog))
		// Remove the first child of 'body', which is our dialog (if any)
		$(dlog).remove();	
}


// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// Place your application-specific JavaScript functions and classes here

//= require_self
// require auth/facebook
//= require common/pics
//= require common/RP
//= require common/dialog
//= require common/notifications
//= require views/edit_recipe
//= require concerns/tagger
//= require jquery/jquery.form
//= require jquery/jquery.ba-postmessage
//= require jquery/jNotify.jquery
//= require jquery/jquery.tokeninput
//= require jquery/jquery.ba-resize
//= require ../../../vendor/assets/javascripts/bootbox

window.RP = window.RP || {}

// Called to replace the form's image with the given URL in response to a message from the owning window
function replaceImg(data) {
	if(data.url && data.url[0])
    pickImg('input#recipe_picurl', 'img.fitPic', data.url[0]);
}

// Function for cracking param string
function ptq(q) {
	/* parse the message */
	/* semicolons are nonstandard but we accept them */
	var x = q.replace(/;/g, '&').split('&'), i, name, t;
	/* q changes from string version of query to object */
	for (q={}, i=0; i<x.length; i++) {
		t = x[i].split('=', 2);
		name = unescape(t[0]);
		if (!q[name])
			q[name] = [];
		if (t.length > 1) {
			q[name][q[name].length] = unescape(t[1]);
		} else
		/* next two lines are nonstandard */
			q[name][q[name].length] = true;
	}
	return q;
}

function launch_interaction(sourcehome) {
	// Set the dialog width to that of the accompanying encapsulation
	if (!(document.referrer && (document.referrer.indexOf(sourcehome) == 0))) // sourcehome matches referrer
		debugger;
	if(sourcehome && sourcehome.length > 0) 
		RP.embedding_url = sourcehome;
	else
		RP.embedding_url = document.referrer
	var dlog = $('div.dialog')[0] // document.getElementById("recipePowerDialog"); // document.body.childNodes[0];
	var onloadNode = dlog.attributes["onload"];
	if(onloadNode) {
		onloadFcn = onloadNode.nodeValue;
		if (onloadFcn && (typeof window[onloadFcn] === 'function'))
			window[onloadFcn](dlog);
	}
       
	RP.dialog.run(dlog); // Hand off submit-handling to the dialog manager
	// $('form', dlog).submit( dlog, submitDialog );
	// Set the dialog's resize function to adjust size of the iframe
	$(dlog).resize( function (evt) {
		var dropdown = $('div.token-input-dropdown-facebook')[0]
		var h = 0;
		if(dropdown && (dropdown.style.display != "none")) {
			h = dropdown.offsetHeight;
		}
		if(dlog.offsetWidth > 0 && dlog.offsetHeight > 0) {
			$.postMessage( { call: "execute_resize", width: dlog.offsetWidth, height: dlog.offsetHeight+h }, RP.embedding_url );
		}
	});
	
	$('div.token-input-dropdown-facebook').resize( function (evt) {
		// Strangely, this do-nothing resize monitor is required to trigger resize of the dialog
		var dropdown = $('div.token-input-dropdown-facebook')[0]
	});
	
	$.receiveMessage( function(evt) {
		var data = ptq(evt.data);
		var call = data.call;
		if(call && (typeof window[call] === 'function')) {
			window[call](data);
		}
	})
}

// Called when the dialog is opened: resize the iframe
function open_dialog(dlog) {
	/// Cancel will remove the dialog and confirm null effect to user
	var cancelBtn = document.getElementById("recipePowerCancelBtn");
	if(cancelBtn) 
		cancelBtn.onclick = retire_iframe;
	// Report the window dimensions to the enclosing iframe
	if(dlog.offsetWidth > 0 && dlog.offsetHeight > 0) 
		$.postMessage( { call: "execute_resize", width: dlog.offsetWidth, height: dlog.offsetHeight }, RP.embedding_url );
}

// Called when the dialog is closed
function close_dialog(dlog) {
	retire_iframe();
}

// Service the click on a link to, say, login with Facebook by loading that URL. The link should contain data for the
// expected width and height of the "dialog"
function yield_iframe(e) {
	var link = e.currentTarget;
	$.postMessage( { call: "redirect_from_iframe", url: $(link).attr("href") }, RP.embedding_url );
	e.stopPropagation();
	e.preventDefault();
	false
}

function retire_iframe(notice) {
	var msg = { call: "retire_iframe" };
	if(notice && (typeof notice === 'string'))
		msg.notice = notice;
	$.postMessage( msg, RP.embedding_url );
}

function redirect_to(url) {
	var msg = { call: "redirect_to", url: url };
	$.postMessage( msg, RP.embedding_url );
}

// A submit handler for a modal dialog form. Submits the data 
// request and stores the response so it can be used when the dialog is closed.
/*
function submitDialog(eventdata) { // Supports multiple forms in dialog
	var context = this;
	var dlog = eventdata.data; // As stored when the dialog was set up
	var process_result_normally = false;
	eventdata.preventDefault();
	/* To sort out errors from subsequent dialogs, we submit the form asynchronously
	   and use the result to determine whether to do normal forms processing. * /
	$(context).ajaxSubmit( {
		async: false,
		dataType: 'json',
		error: function(jqXHR, textStatus, errorThrown) {
			retire_iframe(); // closeDialog(dlog);
			process_result_normally = false;
		},
		success: function (responseData, statusText, xhr, form) {
			process_result_normally = false; // postSuccess(responseData, dlog);
			if(responseData.match(/.*<!.*DOCTYPE\b.*\bhtml\b.*>/i)) {
				// Replace the current document's content with the response
				document.open();
				document.write(responseData);
				document.close();
			} else {
			  var child;
				while(child = document.body.childNodes[0]) {
					if(child.style)
						child.style.visibility = 'hidden';
					document.body.removeChild(child);
				}
				if(responseData.length > 0) {
					jNotify(responseData, { 
						HorizontalPosition: 'center', 
						VerticalPosition: 'top', 
						TimeShown: 2500,
						onClosed: retire_iframe 
					} );
				} else
					retire_iframe();
			}
		}
	});
	return process_result_normally;
}
*/

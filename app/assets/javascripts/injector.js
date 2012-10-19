// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// Place your application-specific JavaScript functions and classes here

//= require pics
//= require jquery.tokeninput
//= require jquery.form
//= require jquery.ba-postmessage
//= require RPPicPicker
//= require jNotify.jquery

// A submit handler for a modal dialog form. Submits the data 
// request and stores the response so it can be used when the dialog is closed.
function submitDialog(eventdata) { // Supports multiple forms in dialog
	var context = this;
	var dlog = eventdata.data; // As stored when the dialog was set up
	var process_result_normally = false;
	eventdata.preventDefault();
	/* To sort out errors from subsequent dialogs, we submit the form asynchronously
	   and use the result to determine whether to do normal forms processing. */
	$(context).ajaxSubmit( {
		async: false,
		dataType: 'html',
		error: function(jqXHR, textStatus, errorThrown) {
			// postError(jqXHR, dlog);
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

function armDialog(sourcehome) {
	// Set the dialog width to that of the accompanying encapsulation
	if(sourcehome && sourcehome.length > 0) document.sourcehome = sourcehome;

	var dlog = document.getElementById("recipePowerDialog"); // document.body.childNodes[0];
	var onloadNode = dlog.attributes["onload"];
	if(onloadNode) {
		onloadFcn = onloadNode.nodeValue;
		if (onloadFcn && (typeof window[onloadFcn] === 'function'))
			window[onloadFcn](dlog);
	}
       
	/// Cancel will remove the dialog and confirm null effect to user
	var cancelBtn = document.getElementById("recipePowerCancelBtn");
	if(cancelBtn) cancelBtn.onclick = retire_iframe;
	$('form', dlog).submit( dlog, submitDialog );
		
	// Finally, report the window dimensions to the enclosing window
	$.postMessage( { call: "execute_resize", width: dlog.offsetWidth, height: dlog.offsetHeight }, document.sourcehome );
	
	// Set up jquery tokeninput for the tags
	$("#recipe_tag_tokens").tokenInput("/tags/match.json", {
		crossDomain: false,
		noResultsText: "No matching tag found; hit Enter to make it a tag",
		hintText: "Type your own tag(s) for the recipe",
		prePopulate: $("#recipe_tag_tokens").data("pre"),
		theme: "facebook",
		preventDuplicates: true,
		allowFreeTagging: true // allowCustomEntry: true
	});
    
	$.receiveMessage( function(evt) {
		var data = ptq(evt.data);
		var call = data.call;
		if(call && (typeof window[call] === 'function')) {
			window[call](data);
		}
	})
}
	
function retire_iframe(notice) {
	var msg = { call: "retire_iframe" };
	if(notice)
		msg.notice = notice;
	$.postMessage( msg, document.sourcehome );
}

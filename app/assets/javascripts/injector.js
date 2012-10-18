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
		dataType: 'json',
		error: function(jqXHR, textStatus, errorThrown) {
			// postError(jqXHR, dlog);
			retire_iframe(); // closeDialog(dlog);
			process_result_normally = false;
		},
		success: function (responseData, statusText, xhr, form) {
			process_result_normally = false; // postSuccess(responseData, dlog);
			retire_iframe(); // closeDialog(dlog);
		}
	});
	return process_result_normally;
}

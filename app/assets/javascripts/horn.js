/* Javascript supporting injected dialogs in arbitrary pages */

function runModal(request, ttl) {
	$('<div>').dialog({
	  open: function(){ $(this).load( request+"?partial=modal" ); },
		width: 900,
		title: ttl
	});
}

// Send a request for HTML to run a dialog, making no assumptions about the environment
function recipePowerGetAndRun(request, mode) {
  if(mode === "modal") {
	runModal(request);
  } else {
	mode = mode || "top";
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
	      assertDialog(xmlhttp.responseText, mode);
	    }
	  }
	  xmlhttp.open("GET", request+"?partial="+mode, true);
	  xmlhttp.setRequestHeader("Accept", "text/html" );
	  xmlhttp.send();		
	}
  }
}

// Inject the dialog on the current document, using the given HTML
function assertDialog(code, mode) {
	debugger;
	if($('#RecipePowerInjectedEncapsulation').length == 0) { // XXX depends on jQuery
	  // Need to encapsulate existing body
	  var theFrame = $("<div id='RecipePowerInjectedEncapsulation'></div>");
	  $("body").children()
	    // Put them into their own div
		.wrapAll(theFrame);
	} 
	if($('#RecipePowerInjectedEncapsulation').prev().length > 0) {
	  // Page has existing dialog => Remove it
	  // Clean up javascript namespace
	  $('#RecipePowerInjectedEncapsulation').prev().remove();
	}
	// Now the page is ready to receive the code
	$("body").prepend($(code));
	// Ensure that all scripts are loaded
	// Run after-load functions
	// Run dialog
  if(mode === "modal") {
	// $("body").append(code);
	debugger;
	$('div.RecipePowerInjector').dialog( 
	  {
		modal: true,
		width: 900,
		title: "Sign In Please"
	  });	
  } else if (mode === "top") {
	debugger;
	$('form').submit( function(eventdata) { // Supports multiple forms in dialog
	    $.ajax({
	        url: eventdata.srcElement.action,
	        type: 'post',
	        dataType: 'json',
	        data: $(eventdata.srcElement).serialize()
	    });
	})
  }
}

// Remove the dialog and injected code
function withdrawDialog() {
	// Remove the first child of 'body', which is our dialog (if any)
	$('#RecipePowerInjectedEncapsulation').prev().remove();
	/* Unwrap the page contents from their encapsulation */
	$('#RecipePowerInjectedEncapsulation').children().unwrap();
}

// Rudimentary test: open and close a dialog space at window top
function fireSpaceTaker() {
	recipePowerGetAndRun("spacetaker"); // openOrInsertDialog("spacetaker")
}

// Do the login dialog
function fireLogin() {
	recipePowerGetAndRun("authentications/new", "modal")
}

// Function that blocks an action before the user logs in
/*
function getLogin() {
  jQuery.get( "authentications", {},
    function(body, status, hr) {
	  if(status == "success") {
		$("#container").append(body);
	  	debugger;
		$("div.signin_all_dlog").dialog({
			modal: true,
			width: 900,
			title: "Sign In Please"
		});
	  }
    }, "html" );
}
*/

// Do the "Add A Cookmark" dialog
function fireAddCookmark() {
	
}

// Do the "New Cookmark From URL" dialog
function fireNewCookmark() {
	
}

// Do the cookmark-editing dialog
function fireEditCookmark() {
	
}

/* Javascript supporting injected dialogs in arbitrary pages */

// Send a GET request for HTML to run a dialog, making no assumptions about the environment
// 'where' is either 'modal', 'at_left' or 'at_top'
// NB: THESE REQUESTS GET/EXPECT HTML, not JSON, which may occur elsewhere

// Rudimentary test: open and close a dialog space at window top
function fireSpaceTaker() {
	recipePowerGetAndRunHTML("spacetaker", "at_top"); // openOrInsertDialog("spacetaker")
}

// Do the login dialog
function fireLogin() {
	recipePowerGetAndRunHTML("authentications/new", "modal")
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

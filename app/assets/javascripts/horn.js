/* Javascript supporting injected dialogs in arbitrary pages */

function toggleHorn() {
	if($("div.hornNew").length == 0) {
		/* No "hornNew" div => do hornIn */
		hornIn();
	} else {
		hornOut();
	}
}

/* Put a div at the top of the window, moving all other content down */
function hornIn() {
	// Select all children of <body
	debugger;
	var myDiv = $("<div class='hornOrig'></div>");
	$("body").children()
	// Put them into their own div
		.wrapAll(myDiv);
	$("body").prepend($("<div class='hornNew'></div>"));
	// $("body").append(myDiv);
}

/* Restore the window to its un-horned state */
function hornOut() {
	/* Remove the 'hornNew' div */
	debugger;
	$("div.hornNew").remove();
	/* Unwrap the page contents from "hornOrig" */
	$("div.hornOrig").children().unwrap();
}

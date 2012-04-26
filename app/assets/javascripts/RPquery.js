// Callback to respond to value changes on form elements,
//  triggering immediate response
function queryChange() {
    // queryformHit(this.form, {});
    queryformHit($("form")[0], {});
}

// Callback to respond to select on list owner,
//  triggering immediate response
function queryownerChange() {
    // queryheaderHit(this.form);
    // queryformHit(this.form, {});
	var ownerItem = $('#rcpquery_owner_id')[0];
	var newOwner = ownerItem.value;
	updateRecipeQueryHeader(newOwner);
	updateRecipeQueryResults({});
}

function queryTabOnPaginate(evt) {
	// Pagination spans have an associated value with the page number
	page = evt.currentTarget.getAttribute("value")
	updateRecipeQueryResults({cur_page: page});
    // queryformHit($("form")[0], {page: page});
}

function updateRecipeQueryHeader( newowner ) {
	var query = $.param( {
		'rcpquery': { owner_id: newowner },
		'element': 'querylist_header'
	})
	var queryID = $(".rcpquery_owner_div").attr('value');
	var resp = jQuery.ajax({
		url: "/rcpqueries/"+queryID,
		type: "POST",
		data: query,
		dataType: "html",
	    success: queryheaderUpdate
	});
}

// Handle a hit on the header (backtome link or list selector) by firing off a query-update request
function queryheaderHit(form) {
    var resp = jQuery.ajax({
        type: "POST",
        url: form.action,
        data: "element=querylist_header&" + $(form).serialize(),
        // Submit the data from the form
        dataType: "html",
        success: queryheaderUpdate
    });
}

// Callback for replacing the recipe list header when the update returns
function queryheaderUpdate(resp, succ, xhr) {
    // Just slam the HTML--if any--in there. (Nil response => leave unchanged.)
    if (resp != "") {
        $('#querylist_header').replaceWith(resp);
        // Replace the hit-handler
        $("select#rcpquery_owner_id").change(queryownerChange);
    }
}

// Update the recipe query list due to a change in state. The change is expressed in
// the passed-in hash, which gets sent to the server as a query-update request. The
// returned list gets used to replace the current list.
function updateRecipeQueryResults( queryparams ) {
	debugger;
	var query = $.param({
		'rcpquery': queryparams,
		'element': "tabnum" 
	})
	var queryID = $(".rcpquery_owner_div").attr('value');
	var resp = jQuery.ajax({
		url: "/rcpqueries/"+queryID,
		type: "POST",
		data: query,
		dataType: "html",
		success: queryresultsUpdate
	})
}

// Handle a hit on one of the query fields by POSTing the whole form, then
// (via callback) updating the results list
function queryformHit(form, options) {
	debugger;
	var query = "";
	if(options.page) {
		query = "page="+page+"&"
	}
	query = query+"element=tabnum&" + $(form).serialize()
    var resp =
    jQuery.ajax({
        type: "POST",
        url: form.action,
        data: query,
        // Submit the data from the form
        dataType: "html",
        success: queryresultsUpdate
    }
    );
}

function queryListmodeChange() {
    var form = $("form")[0];
    var formstr = $(form).serialize();
    // Add the popup to the rcpquery params in the form
    var div = $('select#rcpquery_listmode_str')[0];
    var divstr = $(div).serialize();
    var datastr = "element=tabnum&" + formstr + "&" + divstr;
    //...and proceed with the form hit as usual
    var resp =
    jQuery.ajax({
        type: "POST",
        url: form.action,
        data: datastr,
        // Submit the data from the form
        dataType: "html",
        success: queryresultsUpdate
    }
    );
}

// Callback after an update to hit the appropriate recipe tab
function queryresultsUpdate(resp, succ, xhr) {
    // The response is just the index of the tab to hit
    $("#rcpquery_tabset").tabs('load', Number(resp));
    $("select#rcpquery_listmode_str").change(queryListmodeChange);
}

// Called when a tab loads => fit any pics in their frames and enable clicking
// on paging buttons
function queryTabOnLoad() {
    wdwFitImages();
    $("select#rcpquery_listmode_str").change(queryListmodeChange);
	$(".pageclickr").click(queryTabOnPaginate);
	$(".popup").click(servePopup);
	// if(popupItem = $('.popup')[0]) {
		// popupItem.onclick = servePopup;
	// }
	// Activate the tag tokeninput field
    $("#rcpquery_tag_tokens").tokenInput("/tags/match.json", {
        crossDomain: false,
        hintText: "", // "Type tags and strings to look for",
		noResultsText: "No matching tag found; hit Enter to search with text",
        prePopulate: $("#rcpquery_tag_tokens").data("pre"),
        theme: "facebook",
        onAdd: tokenChangeCallback,
        onDelete: tokenChangeCallback,
        allowCustomEntry: true
    });
	$("#rcpquery_tag_tokens").focus();
}

// Called when a tab is selected
function queryTabOnSelect() {
    var x = 2;
}

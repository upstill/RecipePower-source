// Callback to respond to value changes on form elements,
//  triggering immediate response
function queryChange() {
    // queryformHit(this.form, {});
    queryformHit($("form")[0], {});
}

// Callback to respond to select on list owner,
//  triggering immediate response
function queryownerChange() {
    queryheaderHit(this.form);
    queryformHit(this.form, {});
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

// Handle a hit on one of the query fields by POSTing the whole form, then
// (via callback) updating the results list
function queryformHit(form, options) {
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

// Called when a tab loads => fit any pics in their frames and enable clicking
// on paging buttons
function queryTabOnLoad() {
    wdwFitImages();
    $("select#rcpquery_listmode_str").change(queryListmodeChange);
	$(".pageclickr").click(queryTabOnPaginate);
	// Activate the tag tokeninput field
    $("#rcpquery_tag_tokens").tokenInput("/tags/match.json", {
        crossDomain: false,
        hintText: "Type tags and strings to look for",
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

function queryTabOnPaginate(evt) {
	// Pagination spans have an associated value with the page number
	page = evt.currentTarget.getAttribute("value")
    queryformHit($("form")[0], {page: page});
}

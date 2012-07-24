// Setup function for query page
function RPQueryOnLoad() {
	// $("select#rcpquery_querymode_str").change(queryChange);
	// $("select#rcpquery_status").change(queryChange);
	// $("select#rcpquery_owner_id").change(queryownerChange);
	// $('input[id^=\'rcpquery_ratings_attributes\']').change(queryChange);
	
	// Set up tabs for results list
	var val = Number($("#rcpquery_tabset").attr('value'));
	$("#rcpquery_tabset").tabs( {
						// select:queryTabOnSelect, 
						load:queryTabOnLoad, // Once the tab is loaded, go get the content
						selected:val
						});
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

	// Respond to hits on the friends selector
	$("select#rcpquery_friend_id").change(queryFriendsListLoad);
	// $("select#rcpquery_channel_id").change(queryChannelChange);
	
    // Load the 'friends' recipe list
    queryFriendsListLoad();

    // Load the 'channels' recipe list
    queryChannelsListLoad();

    // Load the master recipe list
    queryMasterListLoad();
	
	// $("a#rcpquery_owner_return").click(backToMe);
	// Bring text focus to the tag input field
    $("#rcpquery_tag_tokens").focus();

    $('#accordion').accordion();  
}

// Respond to a change in the friend selector
function queryFriendsListLoad() {
    // queryformHit(this.form, {});
    // Get the value of the selection box
    set = $("select#rcpquery_friend_id");
	querystr = "rcpqueries/relist?list=friend"
	if(set.first) {
		querystr += set.val();
	}
    // Fire off a replacement for the list
	$('#rcpquery_friends_list').load( querystr );
}

// Respond to a change in the friend selector
function queryChannelsListLoad() {
    // queryformHit(this.form, {});
    // Get the value of the selection box
    set = $("select#rcpquery_channel_id");
	querystr = "rcpqueries/relist?list=channel"
	if(set.first) {
		querystr += set.val();
	}
    // Fire off a replacement for the list
	$('#rcpquery_channels_list').load( querystr );
}

// Respond to a change in the friend selector
function queryMasterListLoad() {
	$('#rcpquery_master_list').load( "rcpqueries/relist?list=master" );
}

// Called when a tab loads (after the content has been replaced):
//  -- Set the appropriate event handlers
//	-- fit any pics in their frames and enable clicking on paging buttons
function queryTabOnLoad() {
	// Ensure that we change the list mode upon demand
    $("select#rcpquery_listmode_str").change(queryListmodeChange);

    // Install click handler to load new page 
	$(".pageclickr").click(queryTabOnPaginate);
	
	// Enable recipe-preview popup
	$(".popup").click(servePopup);
    wdwFitImages();
}

// Callback when token set changes: handle as any change to the query form
function tokenChangeCallback(hi, li) {
    var x = 2;
    queryformHit(this[0].form, {});
	// var tokenStr = $("#rcpquery_tag_tokens").tokenInput("get");
	// updateRecipeQueryResults( { tag_tokens: tokenStr })
}

// Handle a hit on one of the query fields by POSTing the whole form, then
// (via callback) updating the results list
function queryformHit(form, options) {
	var query = "";
	var formdata = $(form).serialize();
	query = query+"element=tabnum&" + formdata;
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

// Callback after an update to hit the appropriate recipe tab
function queryresultsUpdate(resp, succ, xhr) {
    // The response is just the index of the tab to hit
    $("#rcpquery_tabset").tabs('load', Number(resp));
    // Load the 'friends' recipe list
    queryFriendsListLoad();
    // Load the 'channels' recipe list
    queryChannelsListLoad();
    // Load the master recipe list
    queryMasterListLoad();
}

// ----------------- Callbacks for interaction events 

// Respond to page selection: replace results list
function queryTabOnPaginate(evt) {
	// Pagination spans have an associated value with the page number
	page = evt.currentTarget.getAttribute("value")
	updateRecipeQueryResults({cur_page: page});
    // queryformHit($("form")[0], {page: page});
}

function queryListmodeChange() {
    var div = $('select#rcpquery_listmode_str')[0];
	updateRecipeQueryResults( { listmode_str: div.value })
}

// --------------- Functions for updating elements based on events 

// Update the recipe query list due to a change in state as expressed in
// the passed-in hash, which gets sent to the server as a query-update request. The
// returned list gets used to replace the current list.
function updateRecipeQueryResults( queryparams ) {
	var query = $.param({
		'rcpquery': queryparams,
		'element': "tabnum" 
	})
	var queryID = $(".rcpquery_query_div").attr('value');
	var resp = jQuery.ajax({
		url: "/rcpqueries/"+queryID,
		type: "POST",
		data: query,
		dataType: "html",
		success: queryresultsUpdate
	})
}

// ----------------------  Obsolete functions (largely based on forms)
/*
// Callback for replacing the recipe list header when the update returns
function queryheaderUpdate(resp, succ, xhr) {
    // Just slam the HTML--if any--in there. (Nil response => leave unchanged.)
    if (resp != "") {
        $('#querylist_header').replaceWith(resp);
        // Replace the hit-handler
        $("select#rcpquery_owner_id").change(queryownerChange);
    }
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

// Callback to respond to value changes on form elements,
//  triggering immediate response
function queryChange() {
    // queryformHit(this.form, {});
    queryformHit($("form")[0], {});
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

function updateRecipeQueryHeader( newowner ) {
	var query = $.param( {
		'rcpquery': { owner_id: newowner },
		'element': 'querylist_header'
	})
	var queryID = $(".rcpquery_query_div").attr('value');
	var resp = jQuery.ajax({
		url: "/rcpqueries/"+queryID,
		type: "POST",
		data: query,
		dataType: "html",
	    success: queryheaderUpdate
	});
}

function queryownerChange() {
    // queryheaderHit(this.form);
    // queryformHit(this.form, {});
	var ownerItem = $('#rcpquery_owner_id')[0];
	var newOwner = $('#rcpquery_owner_id').attr('value'); // ownerItem.value;
	// updateRecipeQueryHeader(newOwner);
	updateRecipeQueryResults({});
}

// Callback to select another tag for editing
function editAnotherTag(hi, li) {
	if (hi && hi.id) {
		$('body').load( "/tags/"+hi.id+"/edit" );
	}
}

*/
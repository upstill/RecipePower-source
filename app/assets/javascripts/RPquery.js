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
        allowFreeTagging: true // allowCustomEntry: true
    });

	// Respond to hits on the friends selector
	$("select#rcpquery_friend_id").change(queryFriendsSelect);
	$("select#rcpquery_channel_id").change(queryFriendsSelect);
	
	// Bring text focus to the tag input field
    $("#rcpquery_tag_tokens").focus();

	var activelist = $('#accordion').attr("data") || "mine";
    $('#accordion').accordion({
		changestart: queryAccordionChangeStart,
		change: queryAccordionChange,
		collapsible: true,
		active: false, 
		autoHeight: false
	});  
	$('#accordion').accordion( "activate", "h3#rcpquery_"+activelist+"_header");
}

// When the accordion changes, we need to load the content of the new section, as needed
function queryAccordionChangeStart(event, ui) {
	queryAccordionUpdatePanel( ui.newContent );
}

// When the accordion changes, we need to load the content of the new section, as needed
function queryAccordionChange(event, ui) {
}

// Common function for enabling elements of recipe lists and pics on query page, after load
function queryOnLoad(imgs) {

    // Install click handler to load new page 
	$(".pageclickr").click(queryTabOnPaginate);
	
	// Enable recipe-preview popup
	$(".popup").click(RP.servePopup);

  imgs.each(function() {
      fitImage(this);
  });
	
}

function queryAccordionUpdatePanel(elmt) {
	var contentID = elmt.attr("id"); // Extract this node's ID
	if(contentID) {
		// The new-section selector may be nil when closing a section w/o opening another
	    var pre = new RegExp("rcpquery_");
	    var post = new RegExp("_content");
	    var listKind = contentID.replace(pre, "").replace(post, "");
		var listID = "rcpquery_"+listKind+"_list_container"; // Substitute "list" for "content" to get ID of list item
		var obj = $("#"+listID);
		if (!obj.hasClass("current")) {
			obj.load( "rcpqueries/relist", { list: listKind }, function( content, status, xhr) {
				if(status == "success") {
					obj.addClass("current");
					queryOnLoad(obj.find("img.fitPic"));
				}
			});
		} else {
			queryOnLoad(obj.find("img.fitPic"));	
		}
	}
}

// Respond to a change in the friend selector
function queryFriendsSelect() {
    // queryformHit(this.form, {});
    // Get the value of the selection box
    var re = new RegExp("_id$")
    var id = this.id.replace(re, "s_list_container")
    $("#"+id).removeClass("current");
    // Notify the server of the change and trigger an update of the current item
    queryformHit(this[0].form, { });
}


// Called when a tab loads (after the content has been replaced):
//  -- Set the appropriate event handlers
//	-- fit any pics in their frames and enable clicking on paging buttons
function queryTabOnLoad(event, ui) {
	// Ensure that we change the list mode upon demand
    $("select#rcpquery_listmode_str").change(queryListmodeChange);
    var imgsel = $("img.fitPic", ui.panel);
    queryOnLoad(imgsel);
}

// Callback when token set changes: handle as any change to the query form
function tokenChangeCallback(hi, li) {
	// Invalidate all lists
	$(".rcplist_container").removeClass("current");
	// Notify the server of the change and update as needed
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
    });
}

// Callback after an update to hit the appropriate recipe tab (etc.)
function queryresultsUpdate(resp, succ, xhr) {
	// Explicitly update the currently-open section
	var active = $("#accordion").accordion("option", "active");
	if (active == 0) {
	    // The response is just the index of the tab to hit
	    $("#rcpquery_tabset").tabs('load', Number(resp));
	} else if (active != null) {
		// Reload the list for the currently-active panel, if any
		queryAccordionUpdatePanel($("#accordion").children().slice((2*active)+1));
	}
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
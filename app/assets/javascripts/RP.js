// GUARANTEED NECESSARY
// Callback to respond to value changes on form elements,
//  triggering immediate response
function queryChange() {
    // queryformHit(this.form);
    queryformHit($("form")[0]);
}

// Callback to respond to select on list owner,
//  triggering immediate response
function queryownerChange() {
    queryheaderHit(this.form);
    queryformHit(this.form);
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

// Handle a hit on one of the query fields by POSTing the whole form, then
// (via callback) updating the results list
function queryformHit(form) {
    var resp =
    jQuery.ajax({
        type: "POST",
        url: form.action,
        data: "element=tabnum&" + $(form).serialize(),
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

// Called when a tab loads => fit any pics in their frames
function queryTabOnLoad() {
    wdwFitImages();
    $("select#rcpquery_listmode_str").change(queryListmodeChange);
}

// Called when a tab is selected
function queryTabOnSelect() {
    var x = 2;
}


// Make orphan tags draggable (not applicable for dynatree)
/*
function treatOrphanTags() {	
    $(".orphantag").multidraggable(
	{
        // containment: "#workpane",
        opacity: 0.7,
        zIndex: 1,
        revert: "invalid"
    }
	);
}
*/

// Called when the tag tabs load to set up dynatree, etc.
function tagTabsOnLoad(event, info) {
    // Set up handler for tag typing
    // Since apparently the entry panel isn't set up when the tabs have loaded,
    // we need to set a timer to periodically look for them.
    var TO = window.setInterval(function() {
        var idselector = "#tag_entry" + info.index;
        // var source = '/tags/match?morph=strings&tabindex=' + info.index;
        // var source = '/tags.json';
        if ($(idselector).length > 0) {
            // $(idselector).autocomplete({source:source, search:tagTabsTakeTyping})
            $(idselector).bind('change', tagTabsTakeTyping);
            $(idselector).bind('keypress', tagTabsTakeTyping);
            $(idselector).bind('input', tagTabsTakeTyping);
            window.clearInterval(TO);
        }
		setupDynatree();
    },
    100);
 	// treatOrphanTags();
    // , helper:"clone"
    $(".tag_tab").droppable({
        drop: tagTabTakeDropFromDynatree,
        hoverClass: "dropGlow",
        tolerance: "pointer"
    });
}

function tagTabTakeDrop(event, info) {
    var drug = info.draggable;
    drug = $(".ui-draggable-dragging");
    // First thing is, collect an array of ids for the dragged elements
    var ids = [];
    var id;
    drug.each(function() {
        var id;
        if (id = (this.getAttribute("id"))) {
            ids.push(id);
        }
    });
    if (ids.length < 1) {
        return;
    }

    // Now get the index of the tab being dropped upon
    var hit = $(this);
    var parent = $(this).parent();
    var children = parent.children();
    var toIndex = $.inArray(this, children);

    // By the way, what tab is active now?
    var fromIndex = $("#tags_tabset").tabs('option', 'selected');

    // Fire off an Ajax call notifying the server of the (re)classification
    jQuery.get("/tags/typify",
    {
        fromtabindex: fromIndex,
        totabindex: toIndex,
        tagids: ids
    },
    function(body, status, instance) {
        // Use the returned IDs to remove the entries from the list
        // First, generate a query string for jQuery from the returned ids
        var refstr = body.map(function(elmt, ix, arr) { return "#" + elmt; }).join(',');
        $(refstr).remove();
        // Could be adding the strings to the target tab, if it's loaded
    },
    "json");
}

function tagTabTakeDropFromDynatree(event, info) {
    var drug = info.draggable;
    drug = $(".ui-draggable-dragging");
    // First thing is, collect an array of ids for the dragged elements
    var ids = [];
    var id;
	var dtNode = $(drug[0]).data("dtSourceNode")
	ids[0] = dtNode.data.key

    // Now get the index of the tab being dropped upon
    var hit = $(this);
    var parent = $(this).parent();
    var children = parent.children();
    var toIndex = $.inArray(this, children);

    // By the way, what tab is active now?
    var fromIndex = $("#tags_tabset").tabs('option', 'selected');

	dtNode.remove();
    // Fire off an Ajax call notifying the server of the (re)classification
    jQuery.get("/tags/typify",
    {
        fromtabindex: fromIndex,
        totabindex: toIndex,
        tagids: ids
    },
    function(body, status, instance) {
        // Use the returned IDs to remove the entries from the list
        // First, generate a query string for jQuery from the returned ids
        // var refstr = body.map(function(elmt, ix, arr) { return "#" + elmt; }).join(',');
        // $(refstr).remove();
        // Could be adding the strings to the target tab, if it's loaded
		var wdwData = getWdwData(); // Get structure containing tabindex, listid and treeid names
		$(wdwData.listTextElement).focus();
    },
    "json");
}

function getWdwData() {
	var tabindex = $("#tags_tabset").tabs('option', 'selected');
	return {
		tabindex: tabindex,
		tagListSelector: "#taglist"+tabindex,
		referentTreeSelector: "#referenttree"+tabindex,
		listTextElement: "#tag_entry"+tabindex
	}
}

// Respond to typing into the search box: hit the server for a list of matching keys
//  tabindex: index of this tab on the tags page
//  typing: the string typed thus far
//	makeormatch: used to force existence of this exact key
//  url: http string used to hit the server
function tagTabsTakeTyping(event, info) {
    // Send current string to server
    // Get back replacement list of keys
    var id = event.srcElement.id;
    // var tabindex = id.match(/(\D*)(\d*)$/)[2];
    // Tab's index ends the id string
    // var taglistSelector = "#taglist" + tabindex;
    var typing = event.srcElement.value;
    var makeormatch = (event.type == "change") && ($(this).attr("lastCharTyped") == 13);
	// For keypress events, just record the last character typed, for future reference
	if(event.type == "keypress") {
		$(this).attr("lastCharTyped", event.keyCode);
		return;
	}
	// if(makeormatch) { 
		// debugger; 
	// }
	var wdwData = getWdwData(); // Get structure containing tabindex, listid and treeid names
	// Reload the dynatree to reflect the typed string
	$(wdwData.tagListSelector).dynatree("option", 
		"initAjax", {
			   url: "/tags/match",
               data: {
					tabindex: wdwData.tabindex,
					unbound_only: true,
					response_format: "dynatree",
					term: typing,
					makeormatch: makeormatch
               }
    });
	var tree = $(wdwData.tagListSelector).dynatree("getTree");
	tree.reload();
	/*
	var resp = jQuery.get(
		"/tags/match",
	    {
	        tabindex: tabindex,
	        term: typing,
	        makeormatch: makeormatch
	    },
	    function(body, status, instance) { 
			$(taglistSelector).replaceWith(body); 
			treatOrphanTags();
		},
	    "html"
	    );
	*/
}

// Here's how to setup a wrapper method:
/*
(function($){
  $.fn.mycheck = function() {
	var val = $("#tags_tabset").tabs('option', 'selected');
	// debugger;
    return 1;
  };
})(jQuery);
*/


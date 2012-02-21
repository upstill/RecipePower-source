// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
//= require_directory .
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
    debugger;
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
        // var refstr = "nothing really"; // body.map(function(elmt, ix, arr) { return "#" + elmt; }).join(',');
        // $(refstr).remove();
        // Could be adding the strings to the target tab, if it's loaded
    },
    "json");
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
    var tabindex = id.match(/(\D*)(\d*)$/)[2];
    // Tab index ends the id string
    var taglistSelector = "#taglist" + tabindex;
    var typing = event.srcElement.value;
    var makeormatch = event.srcElement.type == "change";
    debugger;
    var resp = jQuery.get("/tags/match",
    {
        tabindex: tabindex,
        term: typing,
        makeormatch: makeormatch
    },
    function(body, status, instance) {
        $(taglistSelector).replaceWith(body);
    },
    "html"
    );
}

// Called when the tag tabs load
function tagTabsOnLoad(event, info) {
    // Set up handler for tag typing
    // Since apparently the entry panel isn't set up when the tabs have loaded,
    // we need to set a timer to periodically look for them.
    var TO = window.setInterval(function() {
        var idselector = "#tag_entry" + info.index;
        var source = '/tags/match?morph=strings&tabindex=' + info.index;
        // var source = '/tags.json';
        if ($(idselector).length > 0) {
            // $(idselector).autocomplete({source:source, search:tagTabsTakeTyping})
            // $(idselector).bind('change', tagTabsTakeTyping);
            // $(idselector).bind('input', tagTabsTakeTyping);
            window.clearInterval(TO);
        }
    },
    100);
    $(".orphantag").multidraggable({
        containment: "#workpane",
        opacity: 0.7,
        zIndex: 1,
        revert: "invalid"
    });
    // , helper:"clone"
    $(".tag_tab").droppable({
        drop: tagTabTakeDrop,
        hoverClass: "dropGlow",
        tolerance: "pointer"
    });
}

// Check that the images in a window have been loaded, fitting them into
// their frames when the size is available.
function wdwFitImages() {
    var TO = window.setInterval(function() {
        var allDone = true;
        $("img.fitPic").each(function() {
            allDone = fitImage(this) && allDone;
        });
        if (allDone) {
            window.clearInterval(TO);
        }
    },
    100);
}

function fitImage(img) {

    if (!img.complete) {
        return false;
    }

    var width = img.parentElement.clientWidth;
    var height = img.parentElement.clientHeight;

    var aspect = img.width / img.height;
    // 'shrinkage' is the scale factor, offsets are for centering the result
    var shrinkage,
    offsetX = 0,
    offsetY = 0;
    if (aspect > width / height) {
        // If the image is wider than the frame
        // Shrink to just fit in width
        shrinkage = width / img.width;
        offsetY = (height - img.height * shrinkage) / 2;
    } else {
        // Shrink to just fit in height
        shrinkage = height / img.height;
        offsetX = (width - img.width * shrinkage) / 2;
    }
    // Scale the image dimensions to fit its parent's box
    // img.width *= shrinkage;
    $(img).css("width", img.width * shrinkage);
    img.style.position = "relative";
    $(img).css("top", offsetY);
    $(img).css("left", offsetX);
    $(img).css("visibility", "visible");
    return true;
}

// Callback when token set changes
function tokenChangeCallback(hi, li) {
    var x = 2;
    queryformHit(this[0].form);
}

// NOT YET GUARANTEED
// Responder for link to return to the user's list
function backToMe(uid) {
    debugger;
    var x = 2;
}

// Callback when query text changes
// function textChangeCallback( ) {
// var x = 2;
// queryformHit(this[0].form);
// }
function alertIframeSelection() {
    var iframe = document.getElementById("viewframe");
    alert(getIframeSelectionText(iframe));
};

function alertSelectionText() {
    var editor_body = self.window.document;
    var range;

    if (editor_body.getSelection()) {
        range = editor_body.getSelection();
        alert(range.toString());
    } else if (editor_body.selection.createRange()) {
        range = editor_body.selection.createRange();
        alert(range.text);
    } else return;
}

function makeIframeSelectionRed() {
    var editor_body = self.window.document;
    var range;

    if (editor_body.getSelection()) {
        range = editor_body.getSelection();
    } else if (editor_body.selection.createRange()) {
        range = editor_body.selection.createRange();
    } else return;
    range.pasteHTML("<span style='color: red'>" + range.htmlText + "</span>");

    // var range = document.getElementById("myid").contentWindow.document.selection.createRange();
    // range.pasteHTML("<span style='color: red'>" + range.htmlText + "</span>");
}

function remove_fields(link) {
    $(link).prev("input[type=hidden]").val("1");
    $(link).closest(".fields").hide();
    queryformHit($("form")[0]);
}

function add_fields(link, association, content) {
    var new_id = new Date().getTime();
    var regexp = new RegExp("new_" + association, "g")
    $(link).parent().before(content.replace(regexp, new_id));
}

$(function() {
    $("#recipe_tag_tokens").tokenInput("/tags/match.json", {
        crossDomain: false,
        hintText: "Type your own tag(s) for the recipe",
        prePopulate: $("#recipe_tag_tokens").data("pre"),
        theme: "facebook",
        allowCustomEntry: true
    });
    $("#rcpquery_tag_tokens").tokenInput("/tags/match.json", {
        crossDomain: false,
        hintText: "Type tags to look for",
        prePopulate: $("#rcpquery_tag_tokens").data("pre"),
        theme: "facebook",
        onAdd: tokenChangeCallback,
        onDelete: tokenChangeCallback,
        allowCustomEntry: true
    });
});

function add_rating(link, association, content) {
    // Get the selected option
    var opts = link.options;
    var selection_ix;
    for (var i = 0; i < opts.length; i++) {
        if (opts[i].selected) {
            selection_ix = i;
        }
    }
    // We expect to get the scale's ID to initialize the fields
    var scale_id_sub = new RegExp("rating_scale_id", "g")

    var rating_id_sub = new RegExp("new_" + association, "g")
    var rating_id = new Date().getTime();

    var name_sub = new RegExp("rating_rname", "g")
    var minlabel_sub = new RegExp("rating_minlabel", "g")
    var maxlabel_sub = new RegExp("rating_maxlabel", "g")

    var labels = opts[selection_ix].title.split(" to ");
    var scalename = opts[selection_ix].text;
    var scale_minlabel = labels[0];
    var scale_maxlabel = labels[1];
    // Substitute labels for the rating, then deploy the scale
    $(link).after(content.
    replace(rating_id_sub, rating_id).
    replace(name_sub, scalename).
    replace(minlabel_sub, scale_minlabel).
    replace(maxlabel_sub, scale_maxlabel).
    replace(scale_id_sub, opts[selection_ix].value));
    // The chosen value
    opts[selection_ix] = null;
    var radbtns = $('input[id^=\'rcpquery_ratings_attributes\']');
    $('input[id^=\'rcpquery_ratings_attributes\']').change(queryChange);
    // if(link.options.length < 2) {
    // Once the last rating is selected and deployed,
    // change the prompt and deactivate the control
    // opts[0].prompt = "No more scales to add";
    // debugger();
    // }
}


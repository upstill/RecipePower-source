/* Paste-event handler to load up the tag pane with the clipboard contents,
   AFTER sending it to the server for vetting */
function takePaste(event) {
    var $this = $(this); //save reference to element for use laster
    // var str = event.originalEvent.clipboardData.getData("text/plain");

    var html = event.originalEvent.clipboardData.getData("text/html");
    // XXX ...because we should be preserving microformat tags
    setTimeout(function(){ //break the callstack to let the event finish

    // $(".tagpane").replaceWith("<div class=\"tagpane\">"+str+"</div>");
    // $this.replaceWith("<div class=\"tagpane\">"+str+"</div>");
    tagpane_paste(html);
    $(".tagpane").bind('paste', takePaste);

	  },0); 
	  }

// Get the selection from the iframe and load it into the tag pane
/* Obsolete, inasmuch as we can't get the selection from a remote site
XXX Eventually, hopefully, we'll be able to replicate said site locally
function tagpane_load() {
    var iframe = document.getElementById("viewframe");
    var sel = rangy.getIframeSelection(iframe);
debugger;
    var str = sel.toHtml();
    $(".tagpane").replaceWith("<div class=\"tagpane\"><pre>"+str+"</pre></div>");
var x = 2;
}
*/

function replaceTagPane( resp, succ, xhr ) {
    $(".tagpane").replaceWith("<div class=\"tagpane\">"+resp+"</div>");
}

// Replace the tagpane with the response from the server after
// it's had a chance to parse the submitted html
function tagpane_paste(html) {
   var data = {html: html, class: "hrecipe"};
   jQuery.post("/recipes/parse", data, replaceTagPane, "html");
}

// Read the state of the tagpane, serialize, and send to server
function tagpane_submit() {
   var datastr = "element=tabnum&"+$('form').serialize(); // Submit the data from the form
debugger;
   datastr = $('.tagpane')[0].innerHTML;
   var action = $('form')[0].action;
   var data = { recipe: {tagpane: datastr }};
   jQuery.post(action, data, replaceTagPane, "html");
}

/* This function responds to the user indicating that a selection range
 * should have a certain class (ingredient, unit, etc.). We do this in consultation
 * with the server, giving it an opportunity to parse the selection into finer units.
 * For example, if the user selects "1 cup" and hits the "Amount" button, the server
 * <may> also classify "1" as "Quantity" and "cup" as "unit".
 */
function applyClass(classname) {
  var sel = rangy.getSelection();
  if(sel.rangeCount>0) { // There is, in fact, a selection
  /* Rangy functions:
  canSurroundContents()
  surroundContents(node): surround contents with this node, replacing range
  	(throws an error if range overlaps node boundaries)
  toHtml(): get text representing range
  compareNode(node): compare node to the range:
  	NODE_BEFORE: the node starts before the range
	NODE_AFTER: the node ends after the range
	NODE_BEFORE_AND_AFTER: the node starts before and ends after the range
	NODE_INSIDE: the node is completely contained within the range
  commonAncestorContainer: lowest node containing both ends of the range
  */
     var range = sel.getRangeAt(0);
     if(!range.collapsed) {
        // Adjust the range to begin and end at word boundaries
	var startContainer = range.startContainer;
	var endContainer = range.endContainer;
	var startOffset = range.startOffset;
	var endOffset = range.endOffset;
	var str = startContainer.data;

	var peg = endOffset;
	if(startContainer != endContainer) {
	    peg = startContainer.data.length;
	}
	peg = findWordBound( str, startOffset, peg, true );
	range.setStart(startContainer, peg );

	if(startContainer != endContainer) {
	    peg = 0;
	    str = endContainer.data;
	}
	if(endOffset > peg) {
	    peg = findWordBound( str, peg, endOffset, false );
	    range.setEnd(startContainer, peg );
	}

	// range.setStartBefore(range.startContainer);
	     // range.setEndAfter(range.endContainer);
	     // range.commonAncestorContainer();
        // Encapsulate the contents
	var html = range.toHtml();
        // Post contents to the server for modification
	var data = {html: html, class: classname };
	jQuery.post("/recipes/parse", data, function( resp, succ, xhr ) {
		var parsedHTML = range.createContextualFragment(resp);
		range.deleteContents();
		range.insertNode(parsedHTML);
		var x=2;
	}, "html");

        // Get revised HTML back
        // Replace the selection with revised HTML
     
        // The Olde Waye:
        //cssApplier=rangy.createCssClassApplier(classname,{normalize:true});
        // cssApplier.applyToRange(range);
        //
     }
  }
}

/* Take the current selection in the tagpane and apply one 
   class or the other to it */

function tagpane_ingredient_list() {
    applyClass("ingredients");
}

function tagpane_ingredient() {
    applyClass("ingredient");
}

function tagpane_amount() {
    applyClass("amount");
}

function tagpane_quantity() {
    applyClass("quantity");
}

function tagpane_unit() {
    applyClass("unit");
}

function tagpane_conditions() {
    applyClass("conditions");
}

function tagpane_condition() {
    applyClass("condition");
}

function tagpane_material() {
    applyClass("name");
}

function tagpane_step() {
    applyClass("step");
}

/* Find a word boundary in the given string, starting
 * at 'offset' and bound by 'min' and 'max'. If 'goFwd'
 * is true, we eat non-alpha characters backwards and
 * alpha characters forwards. The return value will always
 * be <= max and >= min. We assume that indexing is 0-based
 * and that there are at least 'max' characters in the string.
 */
function findWordBound(str, start, end, moveStart) {
   var s = str.slice(start, end);
   var sbefore = str.slice(0,start);
   var safter = str.slice(end,str.length);
   /* Contract the string around any non-alphameric chars. at
    * the beginning and end
    */
   var regexpNonwordFwd = /^\W+/;
   var regexpNonwordBack = /\W+$/;
   var regexpWordFwd = /^\w+/;
   var regexpWordBack = /\w+$/;
   var result;
   if(moveStart) {
       // We're moving the start offset forward to eliminate
       // non-word chars. OR backwards to grab more
       if(result = regexpNonwordFwd.exec(s)) {
           // add the length of the match to 'start'
	   start += result[0].length;
	   if(start>end)
	      return end;
	   else
	      return start;
       } else if(result = regexpWordBack.exec(sbefore)) {
           // subtract the length of the match from 'start'
	   return start-result[0].length; // No need to worry about lower bound
       } else {
           return start;
       }
   } else {
       // We're moving end
       if(result = regexpNonwordBack.exec(s)) {
           end -= result[0].length;
	   if(end<start)
	       return start;
	   else
	       return end;
       } else if(result = regexpWordFwd.exec(safter)) {
           return end + result[0].length;
       } else {
           return end;
       }
   }
}


// Bind tokenInput to the text fields
$(function() {
	$("#referent_children").tokenInput("/tags/match.json", {
	    crossDomain: false,
		noResultsText: "No existing tag found; hit Enter to make a new tag",
	    hintText: "Tags for things that come under this category",
	    prePopulate: $("#referent_children").data("pre"),
	    theme: "facebook",
		preventDuplicates: true,
	    allowCustomEntry: true
	});
	$("#referent_parents").tokenInput("/tags/match.json", {
	    crossDomain: false,
		noResultsText: "No existing tag found; hit Enter to make a new tag",
	    hintText: "Categories that include this",
	    prePopulate: $("#referent_parents").data("pre"),
	    theme: "facebook",
		preventDuplicates: true,
	    allowCustomEntry: true
	});
	$("#referent_add_expression").tokenInput("/tags/match.json", {
	    crossDomain: false,
		noResultsText: "No existing tag found; hit Enter to make a new tag",
	    hintText: "Type/select another tag to express this thing",
	    theme: "facebook",
		tokenLimit: 1,
	    onAdd: add_expression, // Respond to tag selection by adding expression
		preventDuplicates: true,
	    allowCustomEntry: true
	});
});

/* Callback for the selection of a new tag for an expression */
function add_expression(hi, li) {
	// hi.id is the tag id; hi.data is the string
	var that = $('.add_fields')
    time = new Date().getTime()
    regexp = new RegExp($(that).data('id'), 'g')
    newfields = $(that).data('fields').replace(regexp, time);
	regexp = new RegExp("\\*\\*no tag\\*\\*", 'g')
	newfields = newfields.replace(regexp, hi.name)
	regexp = new RegExp("type=.hidden.")
	var valstr = "type=\"hidden\" value=\""+hi.id+"\""
	newfields = newfields.replace(regexp, valstr)
    debugger;
    $(that).before(newfields)
}
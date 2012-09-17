
// Ensure that functionality is available for the editRecipe dialog
function editRecipeOnload() {
    $("#recipe_tag_tokens").tokenInput("/tags/match.json", {
        crossDomain: false,
		noResultsText: "No matching tag found; hit Enter to make it a tag",
        hintText: "Type your own tag(s) for the recipe",
        prePopulate: $("#recipe_tag_tokens").data("pre"),
        theme: "facebook",
		preventDuplicates: true,
        allowCustomEntry: true
    });
	$("#PicPicker").click( function(event) {
		debugger;
		PicPicker("Pick a Picture for the Recipe");
		event.preventDefault();
	})
	fitImageOnLoad("div.editRecipe img");
}

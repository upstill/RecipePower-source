function editRecipeOnload(dlog) {
    $("#recipe_tag_tokens").tokenInput("/tags/match.json", {
        crossDomain: false,
		noResultsText: "No matching tag found; hit Enter to make it a tag",
        hintText: "Type your own tag(s) for the recipe",
        prePopulate: $("#recipe_tag_tokens").data("pre"),
        theme: "facebook",
		preventDuplicates: true,
        allowFreeTagging: true // allowCustomEntry: true
    });
	$("#PicPicker").click( function(event) {
		PicPicker("Pick a Picture for the Recipe");
		event.preventDefault();
	})
	fitImageOnLoad("div.editRecipe img");
	dialogOnClose( dlog, recipeCallback )
}

function newRecipeOnload(dlog) {
	dialogOnClose( dlog, recipeCallback )
}

function genericHandling(data, preface) {
  if(data.error) {
    postError( preface+data.error );
  } else if(data.notice) {
	postNotice( data.notice );
  }
}

// General handling for recipe controller responses
function recipeCallback( data ) {
	if(data.go_link_class) {
	    $("."+data.go_link_class).replaceWith(data.go_link_body);
	}
	if(data.list_element_class) {
		$('.'+data.list_element_class).replaceWith(data.list_element_body);
	    boostInTablist(data.list_element_class, data.list_element_body, 3) // Put it at the top of My Cookmarks
	    boostInTablist(data.list_element_class, data.list_element_body, 4) // Put it at the top of the Recent tab
	}
	genericHandling(data); // Post errors and notices
}

function editRecipeCallback( responseData ) {
	debugger;
}

// Ensure that functionality is available for the editRecipe dialog
function editRecipeOnload(dlog) {
	debugger;
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
	dialogOnClose( dlog, editRecipeCallback );
}

function collectRecipeCallback( data ) {
  if(data.error) {
    jNotify( "Sorry, couldn't grab cookmark: "+data.error, 
		{ HorizontalPosition: 'center', VerticalPosition: 'top'} );
  } else {
    $("."+data.go_link_class).replaceWith(data.go_link_body);
    boostInTablist(data.list_element_class, data.list_element_body, 3) // Put it at the top of My Cookmarks
    boostInTablist(data.list_element_class, data.list_element_body, 4) // Put it at the top of the Recent tab
    $("div.ack_popup").text(data.title);
    jNotify( "Got it! Now appearing at the top of My Cookmarks.", 
		{ HorizontalPosition: 'center', VerticalPosition: 'top'} );
  }
}

// Called upon successful completion of the dialog
function newRecipeCallback( data ) {
	debugger;
    $("."+data.go_link_class).replaceWith(data.go_link_body);
    boostInTablist(data.list_element_class, data.list_element_body, 3) // Put it at the top of My Cookmarks
    boostInTablist(data.list_element_class, data.list_element_body, 4) // Put it at the top of the Recent tab
    $("div.ack_popup").text(data.title);
    jNotify( "Got it! Now appearing at the top of My Cookmarks.", 
		{ HorizontalPosition: 'center', VerticalPosition: 'top'} );
}

function newRecipeOnload(dlog) {
	dialogOnClose( dlog, newRecipeCallback )
}
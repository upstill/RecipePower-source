
function newRecipeOnload(dlog) {
	dialogOnClose( dlog, RP.rcp_list.update )
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

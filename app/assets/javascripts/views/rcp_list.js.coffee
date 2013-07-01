RP.rcp_list = RP.rcp_list || {}

RP.rcp_list.onload = ->
	$(".popup").click(RP.servePopup);

# Callback to update content in a recipe list due to JSON feedback
RP.rcp_list.update = ( data ) ->
	if data.action == "remove" || data.action == "destroy"
		$('.'+data.list_element_class).remove()
		$('.'+data.grid_element_class).remove()
	else if replacements = data.replacements
		for replacement in replacements
			$(replacement[0]).replaceWith replacement[1]
		data.replacements = [] # Prevent the normal processor from reloading the elements
		if data.go_link_class 
			$("."+data.go_link_class).replaceWith data.go_link_body
		if data.list_element_class
			$('.'+data.list_element_class).replaceWith data.list_element_body
			# RP.rcp_list.boostInRecent data.list_element_class, data.list_element_body, 3 # Put it at the top of My Cookmarks
			# RP.rcp_list.boostInRecent data.list_element_class, data.list_element_body, 4 # Put it at the top of the Recent tab
		if data.grid_element_class
			$('.'+data.grid_element_class).replaceWith data.grid_element_body
		checkForLoading ".stuffypic"

RP.rcp_list.boostInRecent = (list_element_class, list_element_body, targettab) ->
	# Insert the resulting element at the top of the All Cookmarks tab, if open
	tabid = $("#rcpquery_tabset").tabs("option", "active");
	if tabid==targettab 
		$("#rcplist_mine_body ."+list_element_class).remove()
		$("#rcplist_mine_body").prepend(list_element_body);

# Report back to the server that a recipe has been touched. In return, get that recipe's 
# list element in the Recent list and place it at the top (removing any that's already 
# there).
RP.rcp_list.touch_recipe = (id) ->		# Formerly rcpTouch from oldRP.js
	# First, replace all the "Recipe last viewed at" lines according to the server
	if id && (id > 0)
		jQuery.get( "/recipes/"+id+"/touch", {}, (body, status, instance) ->
				if status == "success"
					$("."+body.touch_class).replaceWith(body.touch_body);
					# boostInTablist(body.list_element_class, body.list_element_body, 4)
			, "json" )

jQuery ->
	# Enable recipe-preview popup
	RP.rcp_list.onload()

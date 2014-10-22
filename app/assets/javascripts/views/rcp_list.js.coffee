RP.rcp_list = RP.rcp_list || {}

# onload function is overloaded both for individual items and the list as a whole
RP.rcp_list.onload = (item) ->
	if item && (item = $(item)) # Provided when replacing a list element
		if $(item).hasClass('collection-item')
			if img = $('div.rcp_grid_pic_box img', item)[0]
				srcstr = img.getAttribute('src')
				contentstr = "<img src=\""+srcstr+"\" style=\"width: 100%; height: auto\">"
			else
				contentstr = ""
			datablock = $('span.recipe-info-button', item)
			tagstr = $(datablock).data "tags"
			decoded = $('<div/>').html(tagstr).text();
			description = $(datablock).data "description"
			descripted = (description && $('<div/>').html(description).text()) || "";
			$(datablock).popover
				trigger: "hover",
				placement: (context, source) ->
					if source.getBoundingClientRect().left > 300
						"left"
					else
						"right"
				,
				html: true,
				content: descripted+contentstr+decoded
	else
		$('div.collection_list').off 'ajax:beforeSend', '.edit_recipe_link', RP.edit_recipe.go
		$('div.collection_list').on 'ajax:beforeSend', '.edit_recipe_link', RP.edit_recipe.go
		# $('div.collection_list').off 'click', '.popup', RP.servePopup
		# $('div.collection_list').on 'click', '.popup', RP.servePopup

# Callback to update content in a recipe list due to JSON feedback
RP.rcp_list.update = ( data ) ->
	if data.action == "remove" || data.action == "destroy"
		if data.domID && elmt = $('.'+data.domID)[0]
			RP.masonry.removeItem elmt
	else if replacements = data.replacements
		for replacement in replacements
			$(replacement[0]).replaceWith replacement[1]
			RP.rcp_list.onload replacement[0]
		data.replacements = [] # Prevent the normal processor from reloading the elements
		if data.go_link_class 
			$("."+data.go_link_class).replaceWith data.go_link_body
		if data.list_element_class
			$('.'+data.list_element_class).replaceWith data.list_element_body
			# RP.rcp_list.boostInRecent data.list_element_class, data.list_element_body, 3 # Put it at the top of My Cookmarks
			# RP.rcp_list.boostInRecent data.list_element_class, data.list_element_body, 4 # Put it at the top of the Recent tab
		if data.grid_element_class
			$('.'+data.grid_element_class).replaceWith data.grid_element_body
		# checkForLoading ".stuffypic"
		RP.rcp_list.onload()

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

RP.rcp_list = RP.rcp_list || {}

# Callback to update content in a recipe list due to JSON feedback
RP.rcp_list.update = ( data ) ->
	if data.go_link_class 
		$("."+data.go_link_class).replaceWith data.go_link_body
	if data.list_element_class
		$('.'+data.list_element_class).replaceWith data.list_element_body
		img = $('.'+data.list_element_class+' '+'img.fitPic')
		debugger
		$(img).load -> 
			debugger
			fitImage img[0]
			x=2
		fitImage img[0]
		# RP.rcp_list.boostInRecent data.list_element_class, data.list_element_body, 3 # Put it at the top of My Cookmarks
		# RP.rcp_list.boostInRecent data.list_element_class, data.list_element_body, 4 # Put it at the top of the Recent tab
	RP.notify data # Post errors and notices

RP.rcp_list.boostInRecent = (list_element_class, list_element_body, targettab) ->
	# Insert the resulting element at the top of the All Cookmarks tab, if open
	tabid = $("#rcpquery_tabset").tabs("option", "selected");
	if tabid==targettab 
		$("#rcplist_mine_body ."+list_element_class).remove()
		$("#rcplist_mine_body").prepend(list_element_body);

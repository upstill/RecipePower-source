RP.new_recipe = RP.new_recipe || {}

# formerly newRecipeOnload
RP.new_recipe.onload = (dlog) ->
	dialogOnClose dlog, RP.rcp_list.update 

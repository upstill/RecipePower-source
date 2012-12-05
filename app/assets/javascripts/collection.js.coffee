# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http:#jashkenas.github.com/coffee-script/
jQuery ->
	$("#tagstxt").tokenInput("/tags/match.json", 
		crossDomain: false,
		hintText: "Type tags and strings to look for",
		noResultsText: "No matching tag found; hit Enter to search with text",
		prePopulate: $("#collection_query_tokens").data("pre"),
		theme: "facebook",
		onAdd: queryChange,
		onDelete: queryChange,
		allowFreeTagging: true
	)
	
	$('.RcpBrowser').click ->
		if(!$(this).hasClass("selected"))
			# Hide all children of currently-selected collection
			selected = $('.RcpBrowser.selected')[0]
			toClose = selected
			while(toClose && elementLevel(toClose) >= elementLevel(this))
				toggleChildren toClose
				toClose = parentOf toClose
			# Deselect current selection
			$(selected).removeClass("selected")
			
			$(this).addClass("selected")
			toggleChildren this # Make all children visible
			data = $(this).data('html')
			if(data)
				$('div.collection_list')[0].innerHTML = data
			$(this).data('html', this.className )
			# Now that the selection is settled, we can fetch the recipe list
			jQuery.ajax(
				type: "POST",
				url: "collection/update",
				data: { selected: this.id },
				dataType: "html",
				success: (resp, succ, xhr) ->
					# Explicitly update the currently-open section
					$('div.collection_list')[0].innerHTML	= resp	
			);
			

# The parent of an element is the first element with a level lower than the element
parentOf = (elmt) ->
	thisLevel = elementLevel elmt
	while(elmt = $(elmt).prev()[0])
		if(elementLevel(elmt) < thisLevel)
			break
	return elmt

# Check an ancestry relation.
# For the ancestor to be above the descendent, it must be the
# first predecessor of the descendant at its level
isAncestor = (ancestor, descendant) ->
	prior = descendant
	targetLevel = elementLevel ancestor
	while(elementLevel(prior) > targetLevel)
		prior = $(prior).prev()[0]
		if(!prior)
			return false
	prior == ancestor

elementLevel = (elmt) ->
	cn = elmt.className
	ix = cn.indexOf('Level')
	if(ix > 0)
		cn.charAt(ix+5)
	else
		"0"

toggleChildren = (me) ->
	myLevel = elementLevel me
	while((me = $(me).next()[0]) && (elementLevel(me) > myLevel))
		$(me).toggle();

# Callback when the query tag set changes
queryChange = (hi, li) ->
	# Invalidate all lists
	# $(".rcplist_container").removeClass("current"); # Bust any cached collections
	# Notify the server of the change and update as needed
	form = $('form.query_form')[0]
	jQuery.ajax(
		type: "POST",
		url: form.action,
		data: $(form).serialize(),
		dataType: "html",
		success: (resp, succ, xhr) ->
			# Explicitly update the currently-open section
			$('div.collection_list')[0].innerHTML	= resp	
	);


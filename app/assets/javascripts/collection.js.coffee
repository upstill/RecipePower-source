RP.collection = RP.collection || {}

jQuery ->
	$(window).resize -> # Fix the height of the browser
		if (elmt = $("div.browser_house")[0]) && (navlinks = $('div#footer_nav_links')[0])
			elmt.style.bottom = (navlinks.offsetHeight + 5).toString() + "px";

	if (elmt = $("div.browser_house")[0]) && (navlinks = $('div#footer_nav_links')[0])
		elmt.style.bottom = (navlinks.offsetHeight + 5).toString() + "px";

	collection_onload()

	# $('div.loader').removeClass "loading"
###
	$("#tagstxt").tokenInput("/tags/match.json",
		crossDomain: false,
		hintText: "",
		noResultsText: "No matching tag found; hit Enter to search with text",
		prePopulate: $("#tagstxt").data("pre"),
		theme: "facebook",
		onAdd: collection_tagchange,
		onDelete: collection_tagchange,
		allowFreeTagging: true,
		placeholder: "Seek and ye shall find...",
		minChars: 2,
		zindex: 1500
	)
###

RP.collection.onload = (event) ->
	collection_onload()

RP.collection.more_to_come = (armed) ->
	if armed
		querypath = $('#seeker_results').data("query-path")
		RP.scroll.set_handler '#seeker_results', ->
			RP.collection.update { next_page: true }, querypath # Fire a "more-content" event
	else
		RP.scroll.set_handler 'div.collection_list', null

collection_onload = () ->
	RP.tagger.onopen()
	$("#tagstxt").first().focus()
	$('.content-streamer').each (ix, elmt) ->
		if (alertstr = $(elmt).data('alert')) && (alertstr.length > 0)
			alert alertstr
		RP.stream.fire $(elmt).data('kind')
		$(elmt).remove()
	# Page buttons do a remote fetch which needs to replace the collection

	$('.pageclickr').bind "ajax:beforeSend", collection_beforeSend
	$('.pageclickr').bind "ajax:success", collection_success
	# checkForLoading ".stuffypic"
	RP.rcp_list.onload()
	RP.collection.justify()

RP.collection.tagchange = () ->
	formitem = $('form.query_form')
	if $(formitem).data("format") == "html"
		formitem.submit()
	else
		RP.collection.update $(formitem).serialize(), $(formitem).attr("action")

# Event responder to ajax:success on the remote collection-query results
collection_success = (evt, data, status, xhr) ->
	collection_update_success data
	
# Event responder to ajax:beforeSend on the remote collection-query results
collection_beforeSend = (evt, xhr, settings) ->
	RP.dialog.cancel() # Close any open modal dialogs
	RP.notifications.wait()
	true
	
collection_update_success = (resp) ->
	# Explicitly update the collection list
	# $('div.loader').removeClass "loading" # Remove progress indicator
	# $('#seeker_table.masonry-container').masonry('destroy')
	RP.process_response resp
	# window.scrollTo(0,0)
	RP.notifications.done()
	collection_onload()

# Fire the current query state at the server and get back a refreshed recipe list
RP.collection.update = (params, querypath) ->
	collection_beforeSend()
	querypath ||= "/collection"
	jQuery.ajax
		type: "POST"
		url: querypath
		data: params
		dataType: "json"
		beforeSend: (xhr) ->
			xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
		error: (jqXHR, textStatus, errorThrown) ->
			RP.notifications.done()
			responseData = RP.post_error jqXHR
			# responseData.how = responseData.how || assumptions.how
			RP.process_response responseData
		success: (resp, succ, xhr) ->
			collection_update_success resp
			history.replaceState null, "RecipePower | Collections", querypath

RP.collection.rejustify = () ->
	$('#seeker_results.masonry-container').masonry()
	
RP.collection.justify = () ->
	# Initialize Masonry handling for list items
	$('#seeker_results.masonry-container').masonry
		columnWidth: 200,
		gutter: 20,
		itemSelector: '.masonry-item'

# Callback when the query tag set changes
# queryChange = (hi, li) ->
	# Invalidate all lists
	# $(".rcplist_container").removeClass("current"); # Bust any cached collections
	# Notify the server of the change and update as needed
	# form = $('form.query_form')[0]
	# RP.collection.update $(form).serialize(), form.action

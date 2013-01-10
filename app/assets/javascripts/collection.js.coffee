# This is a manifest file that'll be compiled into including all the files listed below.
# Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
# be included in the compiled file accessible from http://example.com/assets/application.js
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# the compiled file.
#
# Place your application-specific JavaScript functions and classes here
# This file is automatically included by javascript_include_tag :defaults

#= require_self
#= require_directory ../../../vendor/assets/javascripts/jquery
#= require jquery_ujs

# require_directory ./controllers
# require bm
# require errors
# require expressions
# require invitations
# require referents
# require registrations
# require sites

#  require_directory ./common
#= require common/ajax_loader
#= require common/dialog
#= require common/pics
#= require common/RP
#= require common/RPDialog
# require common/RPDialogs

#= require_directory ./views
# require views/edit_recipe
# require views/pic_picker
# require views/rcp_list

# require injector
# require microformat
# require oldRP
# require rails
# require RPDialogTest
# require RPfields
# require RPquery
# require RPreferent

#= require bootstrap

window.RP = window.RP || {}

jQuery ->
	$('div.loader').removeClass "loading" 
	$("#tagstxt").tokenInput("/tags/match.json",
		crossDomain: false,
		hintText: "",
		noResultsText: "No matching tag found; hit Enter to search with text",
		prePopulate: $("#tagstxt").data("pre"),
		theme: "facebook",
		onAdd: collection_tagchange,
		onDelete: collection_tagchange,
		allowFreeTagging: true
	)
	
	$("#tagstxt").first().focus()	
	$(".pageclickr").click collection_pager
	
	$('.RcpBrowser').click ->
		if !$(this).hasClass("active")
			# Hide all children of currently-selected collection
			selected = $('.RcpBrowser.active')[0]
			toClose = selected
			while(toClose && elementLevel(toClose) >= elementLevel(this))
				toggleChildren toClose
				toClose = parentOf toClose
			# Deselect current selection
			$(selected).removeClass "active"
			
			$(this).addClass "active"
			toggleChildren this # Make all children visible
			data = $(this).data 'html'
			if(data)
				$('div.collection_list')[0].innerHTML = data
			# Now that the selection is settled, we can fetch the recipe list
			collection_update { selected: @id }

collection_tagchange = (params, url) ->
	collection_update $('form.query_form').serialize()
	
collection_update = (params, url) ->
	$('div.loader').addClass "loading" 
	jQuery.ajax
		type: "POST"
		url: (url || "collection/update")
		data: params
		dataType: "html"
		beforeSend: (xhr) ->
			xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
		success: (resp, succ, xhr) ->
			# Explicitly update the collection list
			$('div.loader').removeClass "loading" 
			$('div.collection_list')[0].innerHTML	= resp	
			$(".pageclickr").click(collection_pager)
	
collection_pager = (evt) ->
	# Respond to page selection: replace results list
	# Pagination spans have an associated value with the page number
	collection_update { cur_page: this.getAttribute("value") }

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
		if !prior
			return false
	prior == ancestor

elementLevel = (elmt) ->
	cn = elmt.className
	ix = cn.indexOf 'Level'
	if ix > 0
		cn.charAt ix+5
	else
		"0"

toggleChildren = (me) ->
	myLevel = elementLevel me
	while((me = $(me).next()[0]) && (elementLevel(me) > myLevel))
		$(me).toggle 200

# Callback when the query tag set changes
queryChange = (hi, li) ->
	# Invalidate all lists
	# $(".rcplist_container").removeClass("current"); # Bust any cached collections
	# Notify the server of the change and update as needed
	form = $('form.query_form')[0]
	collection_update $(form).serialize(), form.action

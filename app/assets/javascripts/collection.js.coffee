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
#= require ../../../vendor/assets/javascripts/bootbox
#= require ../../../vendor/assets/javascripts/history

#= require jquery_ujs

#= require authentication

# require_directory ./controllers
# require bm
# require errors
# require expressions
# require invitations
# require referents
# require registrations
# require sites

#  require_directory ./common
#= require common/dialog
#= require common/pics
#= require common/RP
#= require common/notifications
# require common/RPDialog
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
RP.collection = RP.collection || {}

jQuery ->
	# $('div.loader').removeClass "loading" 
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
		zindex: 1500
	)
	
	$("#tagstxt").first().focus()
	$(".pageclickr").click collection_pager

collection_tagchange = (params, url) ->
	RP.collection.update $('form.query_form').serialize(), $('form.query_form')[0].action

collection_pager = (evt) ->
	# Respond to page selection: replace results list
	# Pagination spans have an associated value with the page number
	RP.collection.update { cur_page: this.getAttribute("value") }, this.dataset.url

RP.collection.update = (params, url) ->
	RP.dialog.cancel() # Close any open modal dialogs
	RP.notifications.wait()
	jQuery.ajax
		type: "POST"
		url: (url || "/collection/query")
		data: params
		dataType: "html"
		beforeSend: (xhr) ->
			xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
		success: (resp, succ, xhr) ->
			# Explicitly update the collection list
			# $('div.loader').removeClass "loading" # Remove progress indicator
			$('div.content')[0].innerHTML	= resp	
			$(".pageclickr").click(collection_pager)
			RP.rcp_list.onload()
			window.scrollTo(0,0)
			RP.notifications.done()

# Callback when the query tag set changes
queryChange = (hi, li) ->
	# Invalidate all lists
	# $(".rcplist_container").removeClass("current"); # Bust any cached collections
	# Notify the server of the change and update as needed
	form = $('form.query_form')[0]
	RP.collection.update $(form).serialize(), form.action

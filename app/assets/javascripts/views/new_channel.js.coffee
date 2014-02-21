RP.new_channel = RP.new_channel || {}

me = () ->
	$('div.new_channel')
# When dialog is loaded, activate its functionality
RP.new_channel.onload = (dlog) ->
	dlog = me()
		
	$("#referent_tag_token").tokenInput "/tags/match.json?tagtypes=1,2,3,4,6,7,8,12,14",
		crossDomain: false,
		noResultsText: "No matching tag found; hit Enter to make it a tag",
		hintText: "Select an existing tag--or make up a new one",
		prePopulate: $("#referent_channel_tag").data("pre"),
		theme: "facebook",
		preventDuplicates: true,
		tokenLimit: 1,
		allowFreeTagging: true # allowCustomEntry: true
		
###
	$('input#referent_dependent').change (evt) ->
		if $("#referent_dependent")[0].checked  # "Channel for existing tag" checked
			$("#referent_tag_token").tokenInput "setOptions",
				url: "/tags/match.json?tagtypes=1,2,3,4,6,7,8,12,14",
				noResultsText: "No existing tag found to use as channel",
				hintText: "Type an existing tag for the channel to track",
				allowFreeTagging: false # allowCustomEntry: false
		else
			$("#referent_tag_token").tokenInput "setOptions",
				url: "/tags/match.json?tagtype=0",
				noResultsText: "Hit Enter to make a channel with a new name",
				hintText: "Type a tag naming the channel",
				allowFreeTagging: true # allowCustomEntry: true
###

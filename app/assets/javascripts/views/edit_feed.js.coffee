RP.edit_feed ||= {}

RP.edit_feed.onopen = ->
	RP.tagger.onopen "#feed_tag_tokens"

RP.edit_feed ||= {}

RP.edit_feed.onload = ->
	RP.tagger.onload "#feed_tag_tokens"

RP.edit_user ||= {}

RP.edit_user.onload = ->
	RP.tagger.onload "#user_tag_tokens"
	
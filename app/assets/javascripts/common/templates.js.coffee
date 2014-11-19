RP.templates ||= {}

# Apply the given data to the named (by DOM id) template
RP.templates.interpolate = (src) ->
	templateSelector = 'div.template#'+src.id
	if (templateData = $(templateSelector).data "template") && (srcString = templateData.string)
		# ...but then again, the dialog may be complete without a template
		for own k, v of src.subs
			v ||= ""
			rx1 = RegExp "%%"+k+"%%", "g"
			rx2 = RegExp "%(25)?%(25)?"+k+"%(25)?%(25)?", "g"
			srcString = srcString.replace(rx1, v).replace(rx2, encodeURIComponent(v))
	$(templateSelector).html srcString # This nukes any lingering children as well as initializing the dialog

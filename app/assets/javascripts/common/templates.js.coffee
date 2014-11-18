RP.templates ||= {}

# Apply the given data to the named (by DOM id) template
RP.templates.apply = (data) ->
	template = $('div.template#'+data.templateId)
	data = data.templateData
	if (templateData = $(template).data "template") && (srcString = templateData.string)
		# ...but then again, the dialog may be complete without a template
		for own k, v of data
			v ||= ""
			rx1 = RegExp "%%"+k+"%%", "g"
			rx2 = RegExp "%(25)?%(25)?"+k+"%(25)?%(25)?", "g"
			srcString = srcString.replace(rx1, v).replace(rx2, encodeURIComponent(v))
	$(template).html srcString # This nukes any lingering children as well as initializing the dialog

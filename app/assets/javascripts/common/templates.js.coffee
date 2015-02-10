RP.templates ||= {}

quoteattr = (s, preserveCR) ->
	preserveCR = preserveCR ? '&#13;' : '\n';
	s = ('' + s)
	if s.match(/^data:image/i)
		return s
	s. # Forces the conversion to string.
	replace(/&/g, '&amp;'). # This MUST be the 1st replacement.
	replace(/'/g, '&apos;'). # The 4 other predefined entities, required.
	replace(/"/g, '&quot;').
	replace(/</g, '&lt;').
	replace(/>/g, '&gt;').
	replace(/\r\n/g, preserveCR). # Must be before the next replacement.
	replace(/[\r\n]/g, preserveCR)

# Apply the given data to the named (by DOM id) template
RP.templates.find_and_interpolate = (src) ->
	templateSelector = 'div.template#'+src.id
	if (templateData = $(templateSelector).data "template") && (srcString = templateData.string)
		# ...but then again, the dialog may be complete without a template
		for own k, v of src.subs
			v ||= ""
			rx1 = RegExp "%%"+k+"%%", "g"
			rx2 = RegExp "%(25)?%(25)?"+k+"%(25)?%(25)?", "g"
			if typeof(v) == "number"
				qa = v
				eu = v
			else
				qa = quoteattr(v)
				eu = encodeURIComponent(v)
			srcString = srcString.replace(rx1, qa).replace(rx2, eu)
	srcString # This nukes any lingering children as well as initializing the dialog

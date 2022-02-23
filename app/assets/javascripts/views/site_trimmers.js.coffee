RP.site_trimmers = RP.site_trimmers || {}

RP.site_trimmers.onopen = (pane) ->
	$('select.governor', pane).change ->
		governs = this.attributes['data-governs'].value
		value = this.value
		$('div.'+governs).hide()
		$('div.'+governs+'.'+value).show()

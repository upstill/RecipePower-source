# Support for editing recipe tags

RP.edit_site = RP.edit_site || {}

me = () ->
	$('div.edit_site.dialog')

fix_buttons = (dlog) ->
	$('a.move-finder-up', dlog).attr('disabled', false);
	$('a.move-finder-down', dlog).attr('disabled', false);
	visible_rows = $('div.finder-fields div.row.finder-field:visible', dlog)
	$('a.move-finder-up', visible_rows.first()).attr('disabled', true);
	$('a.move-finder-down', visible_rows.last()).attr('disabled', true);

RP.edit_site.onopen = (dlog) ->
	fix_buttons dlog

# When dialog is loaded, activate its functionality
RP.edit_site.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.edit_site > *').length > 0
		$(dlog).on 'click', '.add_fields', (event) ->
			time = new Date().getTime()
			regexp = new RegExp($(this).data('id'), 'g')
			$(this).before($(this).data('fields').replace(regexp, time))
			$(this).before('<input type="hidden">')
			fix_buttons dlog
			event.preventDefault()
		$(dlog).on 'click', '.move-finder-up', (event) ->
			my_row = $(event.currentTarget).closest('div.row.finder-field')
			next_row = $(my_row).next()
			target = $(my_row).prev().prev()
			$(my_row).detach()
			$(next_row).detach()
			$(my_row).insertBefore(target)
			$(next_row).insertAfter(my_row)
			fix_buttons dlog
			event.preventDefault()
		$(dlog).on 'click', '.move-finder-down', (event) ->
			my_row = $(event.currentTarget).closest('div.row.finder-field')
			next_row = $(my_row).next()
			target = $(next_row).next().next()
			$(my_row).detach()
			$(next_row).detach()
			$(my_row).insertAfter(target)
			$(next_row).insertAfter(my_row)
			fix_buttons dlog
			event.preventDefault()
		$(dlog).on 'click', '.delete-finder', (event) ->
			$('input[type=hidden]', $(this).siblings('div.form-group.hidden')).val('1')
			my_row = $(this).closest('.row')
			$(my_row).hide()
			$('.required', my_row).removeClass('required').removeAttr('required')
			fix_buttons dlog
			event.preventDefault()

		if $('.pic_picker_golink', dlog).length > 0
			# Get the picture picker in background
			RP.pic_picker.load (picdlg) ->
				$('.pic_picker_golink', dlog).removeClass('hide');
			
			# Arm the pic picker to open when clicked
			$(".pic_picker_golink", dlog).click ->
				event.preventDefault()
				return RP.pic_picker.open "Pick a Logo for the Site"
		
		# Fit the site's image into its place
		# fitImageOnLoad "div.pic_preview img"

jQuery ->
	if dlog = me()[0]
 		RP.edit_site.onload dlog

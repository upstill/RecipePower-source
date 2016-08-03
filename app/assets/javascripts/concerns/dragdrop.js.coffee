RP.dragdrop ||= {}

RP.dragdrop.init = (event) ->
	dragee = event.target
	$(dragee).draggable
		revert:  (dropped) ->
			if dropped && $(dropped).hasClass 'primed'
				$(dropped).removeClass 'primed'
				absorber_id = $(dropped).data('href').split('/')[2]
				absorbee_id = $(this).data('href').split('/')[2]
				true; # NB: This is where the absorb action goes
			else
				true
	.each ->
		top = $(this).position().top;
		left = $(this).position().left;
		$(this).data('orgTop', top);
		$(this).data('orgLeft', left);
	$(event.target).droppable
		drop: (event, ui) ->
			absorber_name = $(this).text()
			absorbee_name = $(ui.draggable).text()
			if confirm "Really merge tag '" + absorbee_name + "' into tag '" + absorber_name + "'? This action can't be undone"
				$(this).addClass 'primed'

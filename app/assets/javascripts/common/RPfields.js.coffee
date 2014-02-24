jQuery ->
  $('body').on 'click', 'a.remove_fields', (event) ->
    $(this).prev('input[type=hidden]').val('1')
    $(this).closest('tr').hide()
    event.preventDefault()

  $('body').on 'click', 'a.add_fields', (event) ->
    time = new Date().getTime()
    regexp = new RegExp($(this).data('id'), 'g')
    newfields = $(this).data('fields').replace(regexp, time);
    $(this).before(newfields)
    event.preventDefault()
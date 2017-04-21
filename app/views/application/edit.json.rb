{
  dlog: with_format('html') { render response_service.select_render(:edit) }
}.merge(flash_notify).to_json

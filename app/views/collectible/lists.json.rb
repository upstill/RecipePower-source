{
    dlog: with_format("html") { render response_service.select_render('lists') }
}.merge(flash_notify).to_json

{
    dlog: with_format("html") { render response_service.select_render('tag') }
}.merge(flash_notify).to_json

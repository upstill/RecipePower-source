{
    dlog: with_format("html") { render response_service.select_render('tag') }
}.push_state(:tag).merge(flash_notify).to_json

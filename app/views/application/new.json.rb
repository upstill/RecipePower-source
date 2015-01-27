{
        dlog: with_format("html") { render response_service.select_render }
}.merge(flash_notify).to_json

{
    dlog: with_format("html") { render response_service.select_render }
}.to_json

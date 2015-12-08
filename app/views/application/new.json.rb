{
        dlog: with_format("html") { render response_service.select_render(:new) }
}.merge(push_state).merge(flash_notify).to_json

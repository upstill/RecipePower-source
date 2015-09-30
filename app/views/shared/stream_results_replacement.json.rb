{
    done: true, # If we got here in closing a dialog
    replacements: [
        [ 'div.stream-results', with_format("html") { render "shared/stream_results_placeholder" } ]
    ]
}.merge(push_state).merge(flash_notify).to_json

{
    done: true, # If we got here in closing a dialog
    replacements: [
        pagelet_filter_replacement,
        pagelet_body_replacement(@decorator)
    ]
}.merge(push_state).merge(flash_notify).to_json

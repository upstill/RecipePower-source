{
    done: true,
    replacements: (@replacements || []) + [
        pagelet_body_replacement('filtered_presenter/presentation') ]
}.merge(push_state).merge(flash_notify).to_json

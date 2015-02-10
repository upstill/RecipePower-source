{
    pushState: [ response_service.originator, response_service.page_title ],
    done: true, # If we got here in closing a dialog
    replacements: [
       pagelet_body_replacement(@decorator)
    ]
}.to_json

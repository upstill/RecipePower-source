{
    pushState: [ response_service.originator, response_service.page_title ],
    done: true, # If we got here in closing a dialog
    replacements: [
        [ 'div.stream-results', stream_results_placeholder ]
    ]
}.to_json

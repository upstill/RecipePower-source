{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        [ 'div.stream-results', stream_results_placeholder ]
    ]
}.to_json

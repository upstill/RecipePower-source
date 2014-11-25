{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
       pagelet_body_replacement(@decorator)
    ]
}.to_json

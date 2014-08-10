{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        ['div.stream-results', with_format("html") { sites_table } ]
    ]
}.to_json

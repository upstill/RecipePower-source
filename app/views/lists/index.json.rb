{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        stream_header_replacement("index_stream_header"),
        # ['div.stream-header', with_format("html") { lists_header }],
        ['div.stream-results', with_format("html") { lists_table }]
    ]
}.to_json

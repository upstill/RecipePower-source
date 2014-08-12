{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        stream_element_replacement( :header, "index_stream_header"),
        # ['div.stream-header', with_format("html") { lists_header }],
        stream_element_replacement(:results) { lists_table }
    ]
}.to_json

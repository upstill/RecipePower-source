{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        stream_element_replacement(:header, "recent_stream_header"),
        masonry_results_replacement
    ]
}.to_json

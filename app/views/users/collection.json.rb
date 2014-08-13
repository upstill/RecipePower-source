{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        stream_element_replacement(:header, "collection_stream_header"),
        stream_element_replacement(:results, "shared/stream_results_masonry") << "RP.masonry.onload"
    ]
}.to_json

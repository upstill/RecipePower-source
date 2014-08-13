{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        stream_element_replacement(:results) { references_table }
    ]
}.to_json

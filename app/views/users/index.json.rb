{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        (stream_element_replacement(:"filter-field")) << "RP.tagger.setup",
        stream_element_replacement(:results) { users_table }
    ]
}.to_json

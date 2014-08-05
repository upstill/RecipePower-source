{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        ['div.stream-shell', with_format("html") { render partial: "shared/stream_table", locals: { headers: [ "Reference Type", "URL/Referees", "", "", "" ] } } ]
    ]
}.to_json

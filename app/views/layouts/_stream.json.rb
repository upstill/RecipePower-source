# Generate JSON data for overlaying one standard page (with streamable content) over another
# { replacements: [[ '.stream-header', 'repl hdr' ]]}.to_json
{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements:
        [
            ['.stream-header', with_format("html") { render partial: "stream_header" } ],
            ['span.title', with_format("html") { render partial: "layouts/title" } ],
            ['.stream-nav', with_format("html") { render partial: "collections_navtabs" }],
            ['.stream-search', with_format("html") { render partial: "stream_search" }, "RP.tagger.setup"],
            ['.stream-shell', with_format("html") { render partial: "stream_shell" }]
        ]
}.to_json

# Generate JSON data for overlaying one standard page (with streamable content) over another
# { replacements: [[ '.stream-header', 'repl hdr' ]]}.to_json
{
    pageUrl: response_service.page_url,
    replacements:
        [
            ['.stream-header', with_format("html") { render partial: "stream_header" } ],
            ['span.title', with_format("html") { render partial: "layouts/title" } ],
            ['.stream-nav', with_format("html") { render partial: "stream_nav" }],
            ['.stream-shell', with_format("html") { render partial: "stream_shell" }]
        ]
}.to_json

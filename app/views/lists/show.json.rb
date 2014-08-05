# Generate JSON data for overlaying one standard page (with streamable content) over another
{
    replacements:
        [
            ['span.title', with_format("html") { render partial: "layouts/title" }],
            ['div.stream-shell', with_format("html") { render partial: "stream_masonry" }]
        ]
}.to_json

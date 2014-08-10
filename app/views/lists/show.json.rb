# Generate JSON data for overlaying one standard page (with streamable content) over another
{
    replacements:
        [
            ['span.title', with_format("html") { render partial: "layouts/title" }],
            stream_header_replacement("show_stream_header"),
            # ['div.stream-header', with_format("html") { list_header }],
            ['div.stream-results', with_format("html") { list_show }]
        ]
}.to_json

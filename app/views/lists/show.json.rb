# Generate JSON data for overlaying one standard page (with streamable content) over another
{
    replacements:
        [
            ['span.title', with_format("html") { render partial: "layouts/title" }],
            stream_element_replacement( :header, "show_stream_header"),
            masonry_results_replacement
        ]
}.to_json

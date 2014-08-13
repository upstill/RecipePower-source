# Generate JSON data for overlaying one standard page (with streamable content) over another
{
    replacements:
        [
            ['span.title', with_format("html") { render partial: "layouts/title" }],
            stream_element_replacement( :header, "show_stream_header"),
            stream_element_replacement( :results, "shared/stream_results_masonry") 
        ]
}.to_json

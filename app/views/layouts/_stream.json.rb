# Generate JSON data for overlaying one standard page (with streamable content) over another
# { replacements: [[ '.stream-header', 'repl hdr' ]]}.to_json
{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements:
        [
            stream_element_replacement(:header, "stream_header"),
            ['span.title', with_format("html") { render partial: "layouts/title" } ],
            ['.stream-nav', with_format("html") { render partial: "collections_navtabs" }],
            stream_element_replacement(:search) + ["RP.tagger.setup"], 
            stream_element_replacement(:results, "stream_shell") 
        ]
}.to_json

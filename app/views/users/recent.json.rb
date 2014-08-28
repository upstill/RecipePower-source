pagelet_body_data "recent_pagelet"
=begin
{
    pushState: [ response_service.originator, response_service.page_title ],
    replacements: [
        ['span.title', with_format("html") { render partial: "layouts/title" }],
        stream_element_replacement( :count),
        masonry_results_replacement
    ]
}.to_json
=end

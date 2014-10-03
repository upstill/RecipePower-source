renderstr = with_format("html") { render partial: "results", layout: false }
{
    replacements: [
        [ 'div#suggestions', renderstr ]
    ]
}.to_json
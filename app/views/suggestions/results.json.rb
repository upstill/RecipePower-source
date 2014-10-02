renderstr = with_format("html") { render partial: "slug", layout: false }
{
    replacements: [
        [ 'div#suggestions', renderstr ]
    ]
}.to_json
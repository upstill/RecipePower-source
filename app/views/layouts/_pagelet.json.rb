{
    replacements: [
        ['div.pagelet-body',
         content_tag(:div,
                     with_format('html') { render template: response_service.find_view },
                     class: "pagelet-body",
                     id: pagelet_body_id)
        ]
    ]
}.merge(flash_notify).to_json
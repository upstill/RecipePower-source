{
    replacements: [
        ['div.pagelet-body',
         content_tag(:div,
                     ((pagelet_signin_links||"")+with_format('html') { render template: response_service.find_view }).html_safe,
                     class: pagelet_class,
                     id: pagelet_body_id)
        ]
    ]
}.merge(flash_notify).to_json
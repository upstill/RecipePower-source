{
    replacements: [
        ['div.pagelet-body',
         content_tag(:div,
                     (flash_notifications_div + with_format('html') { render template: response_service.find_view }).html_safe,
                     class: pagelet_class,
                     id: pagelet_body_id)
        ]
    ]
}.merge(push_state).merge(flash_notify).to_json

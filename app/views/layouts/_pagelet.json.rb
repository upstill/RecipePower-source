# TODO: the #find_view should be redundant (a simple render() call should suffice,
# possibly rendered beforehand)
rendering = with_format('html') { render template: response_service.find_view }
rendering += check_for_notifications if current_user
{
    replacements: [
        ['div.pagelet-body',
         content_tag(:div,
                     (flash_notifications_div + rendering).html_safe,
                     class: pagelet_class,
                     id: pagelet_body_id)
        ]
    ]
}.merge(push_state).merge(flash_notify).to_json

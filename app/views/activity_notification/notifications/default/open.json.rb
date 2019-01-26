# When a notification is opened (acknowledged), regenerate the list
domid = "notification_#{@notification.id}"
{
    replacements: [
        [ 'a.dropdown_notification p.notification_count', notification_count(current_user)],
        [ "div.pagelet-body div.notifications div.#{domid} div.unopned_circle" ],
        [ "div.pagelet-body div.notifications div.#{domid} p.list_text a" ],
        [ "div.notification_list_wrapper div.#{domid}"] # Delete from the popup list
    ]
}.merge(flash_notify).to_json
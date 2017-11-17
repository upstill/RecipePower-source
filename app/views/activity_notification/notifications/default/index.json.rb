# When a notification is opened (acknowledged), regenerate the list
{
    replacements: [
        notifications_replacement(current_user, custom_filter: [ "opened_at = NULL" ])
    ]
}.merge(flash_notify).to_json
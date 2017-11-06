# When a notification is opened (acknowledged), regenerate the list
{
    replacements: [
        notifications_replacement(current_user, opened: true)
    ]
}.merge(flash_notify).to_json
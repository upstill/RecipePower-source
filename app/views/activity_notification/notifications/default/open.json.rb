# When a notification is opened (acknowledged), regenerate the list
{
    replacements: [
        notifications_replacement(current_user)
    ]
}.merge(flash_notify).to_json
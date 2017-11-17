# When a notification is opened (acknowledged), regenerate the list
{
    replacements: [
        notifications_replacement(current_user, opened_only: true )
    ]
}.merge(flash_notify).to_json
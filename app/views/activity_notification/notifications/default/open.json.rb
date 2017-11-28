# When a notification is opened (acknowledged), regenerate the list
{
    replacements: [
        notifications_replacement(current_user, index_content: :unopened_simple )
    ]
}.merge(flash_notify).to_json
{
    replacements: [
        user_follow_button_replacement(@user, :button_size => "small"),
        navmenu_replacement(:friends)
    ]
}.merge(flash_notify).to_json

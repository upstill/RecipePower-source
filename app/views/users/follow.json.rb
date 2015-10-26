{
    replacements: [
        # TODO: should be modifying the Cookmates menu
        user_follow_button_replacement(@user, :button_size => "small")
    ]
}.merge(flash_notify).to_json

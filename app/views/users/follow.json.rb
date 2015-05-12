{
    replacements: [
        follow_button_replacement(@user, :button_size => "small")
    ].compact
}.merge(flash_notify).to_json

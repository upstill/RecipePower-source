{
    replacements: [
        follow_button_replacement(response_service.user, :button_size => "small")
    ].compact
}.merge(flash_notify).to_json

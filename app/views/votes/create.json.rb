{
    replacements: [ vote_buttons_replacement(@vote.entity) ]
}.merge(flash_notify).to_json
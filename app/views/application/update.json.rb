# Generic JSON response for updating an @decorator and replacing it wherever it might go
nukeit = (defined?(delete) && delete) || @decorator.destroyed?
replacements = [
    feed_entry_replacement(@decorator, nukeit),
    (nukeit ? collectible_masonry_item_deleter(@decorator) : collectible_masonry_item_replacement(@decorator))
]
{
    done: true, # i.e., editing is finished, close the dialog
    replacements: replacements,
    # followup: collectible_pagelet_followup(@decorator, nukeit)
}.merge(flash_notify).to_json

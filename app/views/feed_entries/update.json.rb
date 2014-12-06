# Generic JSON response for updating an @decorator and replacing it wherever it might go
nukeit = (defined?(delete) && delete) || @decorator.destroyed?
replacements = [
    feed_entry_replacement(@decorator, nukeit)
]
{
    done: true, # i.e., editing is finished, close the dialog
    replacements: replacements,
    # followup: collectible_pagelet_followup(@decorator, nukeit)
}.merge(flash_notify).to_json

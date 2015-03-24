# Generic JSON response for updating a @decorator and replacing it wherever it might go
nukeit = (defined?(delete) && delete) || @decorator.destroyed?
{
    done: true, # i.e., editing is finished, close the dialog
    replacements: (nukeit ? item_deleters(@decorator) : item_replacements(@decorator)),
    # followup: collectible_pagelet_followup(@decorator, nukeit)
}.merge(flash_notify).to_json

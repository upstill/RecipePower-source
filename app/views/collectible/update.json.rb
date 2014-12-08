# Define response structure after editing a collectible
# Generic JSON response for updating an @decorator and replacing it wherever it might go
nukeit = (defined?(delete) && delete) || @decorator.destroyed?
replacements = [
    collect_or_tag_button_replacement(@decorator),
    collectible_masonry_item_replacement(@decorator, nukeit),
    collectible_table_row_replacement(@decorator, nukeit)
]
{
    done: true, # i.e., editing is finished, close the dialog
    replacements: replacements,
    followup: collectible_pagelet_followup(@decorator, nukeit)
}.merge(flash_notify).to_json

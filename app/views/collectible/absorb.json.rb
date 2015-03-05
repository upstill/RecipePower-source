# Define response structure after absorbing one collectible into another
# Generic JSON response for updating an @decorator and replacing it wherever it might go
replacements = [
    collectible_buttons_panel_replacement(@decorator),
    collectible_masonry_item_replacement(@decorator),
    collectible_masonry_item_deleter(@absorbee),
    collectible_table_row_replacement(@decorator),
    collectible_table_row_replacement(@absorbee, true)
]
{
    done: true, # i.e., editing is finished, close the dialog
    replacements: replacements,
    followup: collectible_pagelet_followup(@decorator)
}.merge(flash_notify).to_json

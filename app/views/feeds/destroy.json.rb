{
    followup: pagelet_followup(@decorator, true),
    replacements: [
        feed_table_row_nuker(@feed)
    ]
}.merge(flash_notify).to_json

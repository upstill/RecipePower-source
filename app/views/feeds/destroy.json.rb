{
    followup: pagelet_followup(@feed, true),
    replacements: [
        feed_table_row_nuker(@feed)
    ]
}.merge(flash_notify).to_json

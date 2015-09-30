{
    followup: (pagelet_folloup(@feed) if followup),
    replacements: [
        feed_table_row_replacement(@feed)
    ]
}.merge(flash_notify).to_json

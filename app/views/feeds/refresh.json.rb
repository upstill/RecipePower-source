{
    followup: ({ request: feed_url(@feed, :mode => :partial, :nocache => true ), target: pagelet_body_selector(@feed) } if followup),
    replacements: [
        feed_table_row_replacement(@feed)
    ]
}.merge(flash_notify).to_json
{
    # Go back to the feeds list if we're on the feed's pagelet
    followup: { request: feeds_url(:mode => :partial, :nocache => true, :access => :all ), target: pagelet_body_selector(@feed) },
    replacements: [
        feed_table_row_nuker(@feed)
    ]
}.merge(flash_notify).to_json
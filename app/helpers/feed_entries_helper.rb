module FeedEntriesHelper
  def collect_feed_entry_button fe
    if fe.user_ids.include?(fe.collectible_user_id)
      url = edit_feed_entry_path(fe)
      label = "Edit"
    else
      url = collect_feed_entry_path(fe)
      label = "Collect"
    end
    link_to_submit label, url, class: "collect-feed-entry btn btn-default btn-xs", id: dom_id(fe)
  end

  def collect_feed_entry_button_replacement fe
    [ "a.collect-feed-entry##{dom_id fe}", collect_feed_entry_button(fe) ]
  end
end

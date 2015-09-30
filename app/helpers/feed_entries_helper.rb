module FeedEntriesHelper

  def feed_entry entity
    with_format("html") do render "feed_entries/show_page", item: entity end
  end

  def feed_entry_replacement entity, destroyed=false
    [ "div.feed-entry##{dom_id entity}", (feed_entry entity unless destroyed) ]
  end
end

class AddFeedEntriesCountToFeeds < ActiveRecord::Migration
  def up
    add_column :feeds, :feed_entries_count, :integer, :default => 0
    Feed.find_each { |feed| 
	puts feed.title + '...'
	# feed.perform
	Feed.reset_counters(feed.id, :feed_entries)
	feed.last_post_date = ((fe = feed.feed_entries.first) && fe.published_at) ? fe.published_at : feed.updated_at
	feed.save 
    } # Initialize last_post_date to either the publish date of the last entry, or the last time updated
  end
  def down
    remove_column :feeds, :feed_entries_count
  end
end

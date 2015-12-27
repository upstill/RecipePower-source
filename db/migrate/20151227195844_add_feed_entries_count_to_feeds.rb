class AddFeedEntriesCountToFeeds < ActiveRecord::Migration
  def up
    add_column :feeds, :feed_entries_count, :integer, :default => 0
    Feed.find_each { |feed| Feed.reset_counters(feed.id, :feed_entries) }
  end
  def down
    remove_column :feeds, :feed_entries_count
  end
end

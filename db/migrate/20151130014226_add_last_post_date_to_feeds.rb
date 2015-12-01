class AddLastPostDateToFeeds < ActiveRecord::Migration
  def change
    add_column :feeds, :last_post_date, :datetime
    Feed.all.each { |feed| 
	puts feed.title + '...'
	feed.perform
	feed.last_post_date = ((fe = feed.feed_entries.first) && fe.published_at) ? fe.published_at : feed.created_at
	feed.save 
    } # Initialize last_post_date to either the publish date of the last entry, or the last time updated
  end
end

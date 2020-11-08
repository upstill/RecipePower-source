class RenameRssfeedInGleaning < ActiveRecord::Migration[5.2]
  def change
	remove_column :gleanings, :rss_feed, :text
	add_column :gleanings, :rss_feeds, :text, array: true, default: []
	add_column :page_refs, :rss_feeds, :text, array: true, default: []
  end
end

class AddIndexToFeedEntry < ActiveRecord::Migration
  def change
    add_index :feed_entries, ["feed_id","guid"]
  end
end

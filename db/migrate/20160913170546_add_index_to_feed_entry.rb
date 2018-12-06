class AddIndexToFeedEntry < ActiveRecord::Migration[4.2]
  def change
    add_index :feed_entries, ["feed_id","guid"]
  end
end

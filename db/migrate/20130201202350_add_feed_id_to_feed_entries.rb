class AddFeedIdToFeedEntries < ActiveRecord::Migration
  def change
    add_column :feed_entries, :feed_id, :integer
  end
end

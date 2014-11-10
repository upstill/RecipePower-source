class AddPictureIdToFeedEntries < ActiveRecord::Migration
  def change
    add_column :feed_entries, :picture_id, :integer
    rename_column :feed_entries, :name, :title
  end
end

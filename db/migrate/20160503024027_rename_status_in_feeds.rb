class RenameStatusInFeeds < ActiveRecord::Migration[4.2]
  def change
    rename_column :feeds, :status, :ostatus
    add_column :feeds, :status, :integer, :default => 0
  end
end

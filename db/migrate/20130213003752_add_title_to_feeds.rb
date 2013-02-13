class AddTitleToFeeds < ActiveRecord::Migration
  def up
    add_column :feeds, :title, :string
  end

  def down
    remove_column :feeds, :title, :string
  end
end

class AddHomeToFeeds < ActiveRecord::Migration
  def change
    add_column :feeds, :home, :string
  end
end

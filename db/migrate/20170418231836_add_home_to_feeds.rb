class AddHomeToFeeds < ActiveRecord::Migration[4.2]
  def change
    add_column :feeds, :home, :string
  end
end

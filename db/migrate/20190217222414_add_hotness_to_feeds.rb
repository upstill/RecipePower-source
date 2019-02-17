class AddHotnessToFeeds < ActiveRecord::Migration[5.0]
  def change
    add_column :feeds, :hotness, :integer, default: 0
  end
end

class AddLastPostDateToFeeds < ActiveRecord::Migration
  def change
    add_column :feeds, :last_post_date, :datetime
  end
end

class AddStatusToFeeds < ActiveRecord::Migration
  def change
    add_column :feeds, :status, :string, default: "ready"
  end
end

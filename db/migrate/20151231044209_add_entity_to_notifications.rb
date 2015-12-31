class AddEntityToNotifications < ActiveRecord::Migration
  def change
    add_column :notifications, :shared_type, :string
    add_column :notifications, :shared_id, :integer
  end
end

class AddAcceptedToNotification < ActiveRecord::Migration
  def change
    add_column :notifications, :accepted, :boolean, default: true
  end
end

class AddAutosaveToNotifications < ActiveRecord::Migration
  def change
    add_column :notifications, :autosave, :boolean, :default => false
  end
end

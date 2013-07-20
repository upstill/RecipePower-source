class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.integer :source_id
      t.integer :target_id
      t.integer :notification_type
      t.text :info

      t.timestamps
    end
  end
end

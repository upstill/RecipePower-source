class DropNotificationTable < ActiveRecord::Migration
  def up
    drop_table :notifications
  end
  def down
    create_table "notifications", force: :cascade do |t|
      t.integer  "source_id"
      t.integer  "notification_type"
      t.string   "notification_token", limit: 255
      t.text     "info"
      t.datetime "created_at",                                     null: false
      t.datetime "updated_at",                                     null: false
      t.boolean  "accepted",                       default: true
      t.string   "shared_type"
      t.integer  "shared_id"
      t.boolean  "autosave",                       default: false
    end

  end
end

# Migration responsible for creating a table with notifications
class CreateActivityNotificationTables < ActiveRecord::Migration[4.2]
  # Create tables
  def up
    drop_table(:notifications) if ActiveRecord::Base.connection.table_exists?("notifications")
    create_table :notifications do |t|
      t.belongs_to :target,     polymorphic: true, index: true, null: false
      t.belongs_to :notifiable, polymorphic: true, index: true, null: false
      t.string     :notification_token, limit: 255
      t.string     :key,                                        null: false
      t.belongs_to :group,      polymorphic: true, index: true
      t.integer    :group_owner_id,                index: true
      t.belongs_to :notifier,   polymorphic: true, index: true
      t.text       :parameters
      t.datetime   :opened_at

      t.timestamps
    end

    drop_table(:subscriptions) if ActiveRecord::Base.connection.table_exists?("subscriptions")
    create_table :subscriptions do |t|
      t.belongs_to :target,     polymorphic: true, index: true, null: false
      t.string     :key,                           index: true, null: false
      t.boolean    :subscribing,                                null: false, default: true
      t.boolean    :subscribing_to_email,                       null: false, default: true
      t.datetime   :subscribed_at
      t.datetime   :unsubscribed_at
      t.datetime   :subscribed_to_email_at
      t.datetime   :unsubscribed_to_email_at
      t.text       :optional_targets

      t.timestamps
    end
    add_index :subscriptions, [:target_type, :target_id, :key], unique: true
  end
  def down
    drop_table :notifications
    # remove_index(:subscriptions, name: "references_index_by_id")
    drop_table :subscriptions
  end
end

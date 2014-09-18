class CreateEventNotices < ActiveRecord::Migration
  def change
    create_table :event_notices do |t|
      t.integer :event_id
      t.integer :user_id
      t.boolean :read, default: false

      t.timestamps
    end unless ActiveRecord::Base.connection.table_exists?("event_notices")
  end
end

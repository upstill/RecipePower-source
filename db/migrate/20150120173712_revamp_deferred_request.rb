class RevampDeferredRequest < ActiveRecord::Migration
  def up
    drop_table :deferred_requests
    create_table :deferred_requests, id: false do |t|
      t.string :session_id, null: false
      t.text :requests, default: [].to_yaml

      t.timestamps
    end
    add_index :deferred_requests, "session_id", name: "index_deferred_requests", unique: true

  end
  def down
    drop_table :deferred_requests
    create_table :deferred_requests do |t|
      t.text :requests

      t.timestamps
    end
  end
end

class CreateRpEvents < ActiveRecord::Migration
  def change
    create_table :rp_events do |t|
      t.integer :event_type
      t.integer :user_id
      t.integer :serve_count
      t.boolean :on_mobile

      t.timestamps
    end
  end
end

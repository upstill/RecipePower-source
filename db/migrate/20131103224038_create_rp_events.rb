class CreateRpEvents < ActiveRecord::Migration
  def change
    create_table :rp_events do |t|
      t.integer :verb
      t.integer :source_id
      t.string :subject_type
      t.integer :subject_id
      t.string :object_type
      t.integer :object_id
      t.text :data

      t.timestamps
    end
  end
end

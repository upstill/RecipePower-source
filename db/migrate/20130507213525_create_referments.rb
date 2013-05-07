class CreateReferments < ActiveRecord::Migration
  def change
    create_table :referments do |t|
      t.integer :referent_id
      t.integer :referee_id
      t.string :referee_type

      t.timestamps
    end
  end
end

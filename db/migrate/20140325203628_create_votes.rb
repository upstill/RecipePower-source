class CreateVotes < ActiveRecord::Migration
  def change
    create_table :votes do |t|
      t.integer :user_id
      t.string :entity_type
      t.integer :entity_id
      t.string :original_entity_type
      t.integer :original_entity_id
      t.boolean :up

      t.timestamps
    end
  end
end

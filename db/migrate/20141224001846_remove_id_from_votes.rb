class RemoveIdFromVotes < ActiveRecord::Migration
  def up
    drop_table :votes if ActiveRecord::Base.connection.table_exists?("votes")
      create_table :votes, :id => false do |t|
        t.integer :user_id
        t.string :entity_type
        t.integer :entity_id
        t.boolean :up

        t.timestamps
      end
	add_index :votes, [:user_id, :entity_type, :entity_id], :unique => true 

  end
  def down
    drop_table :votes
  end
end

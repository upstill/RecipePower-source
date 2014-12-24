class CreateVotes < ActiveRecord::Migration
  def up
    unless ActiveRecord::Base.connection.table_exists?("votes")
      create_table :votes do |t|
        t.integer :user_id
        t.string :entity_type
        t.integer :entity_id
        t.boolean :up

        t.timestamps
      end
    end
  end

  def down
    drop_table :votes
  end
end

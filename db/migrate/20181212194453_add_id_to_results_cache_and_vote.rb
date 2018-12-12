# Migration to start over with ResultsCache and Vote eliminating composite primary keys
class AddIdToResultsCacheAndVote < ActiveRecord::Migration[5.0]
  def up
      drop_table :results_caches
      create_table :results_caches, :force => true do |t|
        t.string :session_id, null: false
        t.text :params, :default => {}.to_yaml
        t.text :cache
        t.string :type, null: false
        t.string :result_typestr, default: '', null: false
        t.text :partition

        t.timestamps
      end
      add_index :results_caches, ["session_id","type","result_typestr"], :unique => true

      drop_table :votes
      create_table :votes do |t|
        t.integer :user_id
        t.string :entity_type
        t.integer :entity_id
        t.boolean :up

        t.timestamps
      end
	    add_index :votes, [:user_id, :entity_type, :entity_id], :unique => true
  end
end

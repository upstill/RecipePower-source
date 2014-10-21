class AddPartitionToResultsCaches < ActiveRecord::Migration
  def up
      drop_table :results_caches
      create_table :results_caches, :id => false do |t|
        t.string :session_id
        t.text :params
        t.text :cache
        t.string :type
	t.text :partition

        t.timestamps
      end
      execute "ALTER TABLE results_caches ADD PRIMARY KEY (session_id,type);"
      add_index :results_caches, ["session_id","type"], :unique => true
  end
  def down
      drop_table :results_caches
      create_table :results_caches, :id => false do |t|
        t.string :session_id
        t.text :params
        t.text :cache
        t.string :type
        t.integer :cur_position, default: 0
        t.integer :limit, default: -1

        t.timestamps
      end
      execute "ALTER TABLE results_caches ADD PRIMARY KEY (session_id);"
      add_index :results_caches, :session_id
  end
end

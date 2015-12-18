class AddResultTypeToResultsCaches < ActiveRecord::Migration
  def up
      create_table :results_caches, :force => true, :id => false do |t|
        t.string :session_id
        t.text :params, :default => {}.to_yaml
        t.text :cache
        t.string :type
	t.string :result_typestr, default: ''
	t.text :partition

        t.timestamps
      end
      execute "ALTER TABLE results_caches ADD PRIMARY KEY (session_id,type,result_typestr);"
      add_index :results_caches, ["session_id","type","result_typestr"], :unique => true
  end
  def down
      create_table :results_caches, :force => true, :id => false do |t|
        t.string :session_id
        t.text :params, :default => {}.to_yaml
        t.text :cache
        t.string :type
	t.text :partition

        t.timestamps
      end
      execute "ALTER TABLE results_caches ADD PRIMARY KEY (session_id,type);"
      add_index :results_caches, ["session_id","type"], :unique => true
  end
end

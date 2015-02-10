class CreateResultsCaches < ActiveRecord::Migration
  def change
      create_table :results_caches, :force => true, :id => false do |t|
        t.string :session_id
        t.text :params
        t.text :cache
        t.string :type, null: false, default: ""
        t.integer :cur_position, default: 0
        t.integer :limit, default: -1

        t.timestamps
      end
      add_index :results_caches, :session_id
  end
end

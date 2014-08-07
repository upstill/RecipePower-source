class CreateResultsCaches < ActiveRecord::Migration
  def change
    unless ActiveRecord::Base.connection.table_exists?("results_caches")
      create_table :results_caches, :id => false do |t|
        t.string :session_id
        t.text :params
        t.text :cache
        t.string :type
        t.integer :cur_position, default: 0
        t.integer :limit, default: -1

        t.timestamps
      end
      add_index :results_caches, :session_id
    end
  end
end

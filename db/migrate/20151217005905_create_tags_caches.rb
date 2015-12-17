class CreateTagsCaches < ActiveRecord::Migration
  def change
      create_table :tags_caches, :force => true, :id => false do |t|
        t.string :session_id
        t.text :tags, :default => {}.to_yaml
      end
      add_index :tags_caches, :session_id
  end
end

class CreateBannedTags < ActiveRecord::Migration[4.2]

  def change
    if ActiveRecord::Base.connection.table_exists?("rcpqueries")
      drop_table :rcpqueries 
    end
    unless ActiveRecord::Base.connection.table_exists?("banned_tags")
      create_table :banned_tags do |t|
        t.string :normalized_name

        t.timestamps null: false
      end
      add_index :banned_tags, :normalized_name, :unique => true
    end
  end
end

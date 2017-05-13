class CreateBannedTags < ActiveRecord::Migration
  def change
    create_table :banned_tags do |t|
      t.string :normalized_name

      t.timestamps null: false
    end
    add_index :banned_tags, :normalized_name, :unique => true
  end
end

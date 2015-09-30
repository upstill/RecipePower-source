class CreateTagSelections < ActiveRecord::Migration
  def change
    drop_table :tag_selections if ActiveRecord::Base.connection.table_exists?("tag_selections")

    create_table :tag_selections do |t|
      t.references :tagset, index: true
      t.references :user, index: true
      t.references :tag, index: true

      t.timestamps null: false
    end
    add_foreign_key :tag_selections, :tagsets
    add_foreign_key :tag_selections, :users
    add_foreign_key :tag_selections, :tags
  end
end

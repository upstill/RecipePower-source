class CreateLists < ActiveRecord::Migration
  def change
    create_table :lists do |t|
      t.integer :owner_id
      t.integer :name_tag_id
      t.text :ordering, default: ""
      t.text :notes, default: ""

      t.timestamps
    end

    create_table :lists_tags do |t|
      t.integer :tag_id
      t.integer :list_id

      t.timestamps
    end
  end
end

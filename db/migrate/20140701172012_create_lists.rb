class CreateLists < ActiveRecord::Migration
  def change
    create_table :lists do |t|
      t.integer :owner_id
      t.integer :tag_id
      t.text :ordering

      t.timestamps
    end
  end
end

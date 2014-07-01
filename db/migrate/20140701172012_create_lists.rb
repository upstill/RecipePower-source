class CreateLists < ActiveRecord::Migration
  def change
    create_table :lists do |t|
      t.integer :owner_id
      t.text :items

      t.timestamps
    end
  end
end

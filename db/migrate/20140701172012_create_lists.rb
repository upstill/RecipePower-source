class CreateLists < ActiveRecord::Migration
  def change
    create_table :lists do |t|
      t.integer :owner
      t.text :items

      t.timestamps
    end
  end
end

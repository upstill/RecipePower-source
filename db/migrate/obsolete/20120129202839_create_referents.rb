class CreateReferents < ActiveRecord::Migration
  def change
    create_table :referents do |t|
      t.integer :tag
      t.integer :parent_id
      t.string :type

      t.timestamps
    end
  end
end

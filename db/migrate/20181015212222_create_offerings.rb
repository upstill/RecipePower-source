class CreateOfferings < ActiveRecord::Migration
  def change
    create_table :offerings do |t|
      t.integer :product_id
      t.integer :page_ref_id

      t.timestamps null: false
    end
  end
end

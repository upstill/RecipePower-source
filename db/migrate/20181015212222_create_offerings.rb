class CreateOfferings < ActiveRecord::Migration
  def up
    drop_table :offerings if ActiveRecord::Base.connection.table_exists?("offerings")
    create_table :offerings do |t|
      t.integer :product_id
      t.integer :page_ref_id

      t.timestamps null: false
    end
  end
  def down
    drop_table :offerings
  end
    
end

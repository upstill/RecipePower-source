class DropLinks < ActiveRecord::Migration
  def up
    drop_table :links
  end

  def down
    create_table :links do |t|
      t.string :domain
      t.text :uri
      t.integer :resource_type
      t.integer :entity_id
      t.string :entity_type

      t.timestamps
    end
  end
end

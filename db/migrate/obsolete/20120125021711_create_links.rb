class CreateLinks < ActiveRecord::Migration
  def self.up
    create_table :links do |t|
      t.string :domain
      t.text :uri
      t.integer :resource_type

      t.timestamps
    end
  end

  def self.down
    drop_table :links
  end

end

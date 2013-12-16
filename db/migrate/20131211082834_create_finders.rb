class CreateFinders < ActiveRecord::Migration
  def change
    create_table :finders do |t|
      t.string :finds
      t.string :selector
      t.string :read_attrib
      t.integer :site_id

      t.timestamps
    end
  end
end

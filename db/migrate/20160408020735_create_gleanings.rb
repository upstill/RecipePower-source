class CreateGleanings < ActiveRecord::Migration
  def change
    create_table :gleanings do |t|
      t.string :entity_type
      t.integer :entity_id
      t.text :page_tags

      t.timestamps null: false
    end
    add_column :finders, :hits, :integer, :default => 0
  end
end

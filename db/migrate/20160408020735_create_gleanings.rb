class CreateGleanings < ActiveRecord::Migration[4.2]
  def change
    drop_table :gleanings if ActiveRecord::Base.connection.table_exists?("gleanings")
    create_table :gleanings do |t|
      t.string :entity_type
      t.integer :entity_id
      t.integer :status, :default => 0
      t.text :results

      t.timestamps null: false
    end
    add_column :finders, :hits, :integer, :default => 0
  end
end

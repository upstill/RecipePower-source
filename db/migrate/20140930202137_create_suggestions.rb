class CreateSuggestions < ActiveRecord::Migration
  def change
    create_table :suggestions do |t|
      t.string :base_type
      t.integer :base_id
      t.integer :viewer
      t.string :session
      t.text :filter
      t.integer :rc
      t.text :results

      t.timestamps
    end
  end
end

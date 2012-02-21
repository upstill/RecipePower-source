class CreateExpressions < ActiveRecord::Migration
  def change
    create_table :expressions do |t|
      t.integer :tag_id
      t.integer :referent_id
      t.integer :form
      t.string :locale

      t.timestamps
    end
    LinkRef.import_file "db/data/FoodLover"
    # Referent.express "dairy", :Food
  end
end

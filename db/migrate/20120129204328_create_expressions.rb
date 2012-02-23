class CreateExpressions < ActiveRecord::Migration
  def change
    create_table :expressions do |t|
      t.integer :tag_id
      t.integer :referent_id
      t.integer :form
      t.string :locale

      t.timestamps
    end
  end
end

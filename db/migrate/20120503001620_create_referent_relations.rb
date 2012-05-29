class CreateReferentRelations < ActiveRecord::Migration
  def change
    create_table :referent_relations do |t|
      t.integer :parent_id
      t.integer :child_id

      t.timestamps
    end
  end
end

class CreateReferentRelations < ActiveRecord::Migration
  def change
    create_table :referent_relations do |t|
      t.integer :referent_id
      t.integer :reference_id

      t.timestamps
    end
  end
end

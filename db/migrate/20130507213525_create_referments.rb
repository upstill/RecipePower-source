class CreateReferments < ActiveRecord::Migration
  def change
    create_table :referments do |t|
      t.integer :referent_id
      t.integer :reference_id

      t.timestamps
    end
  end
end

class CreateTagOwners < ActiveRecord::Migration
  def change
    create_table :tag_owners do |t|
      t.integer :tag_id
      t.integer :user_id

      t.timestamps
    end
  end
end

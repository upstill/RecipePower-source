class DropTouches < ActiveRecord::Migration
  def up
	Touch.fix
	drop_table :touches
	change_column :rcprefs, :in_collection, :boolean, :default => false

  end

  def down
    create_table :touches do |t|
      t.integer :user_id
      t.integer :recipe_id

      t.timestamps
    end
    change_column :rcprefs, :in_collection, :boolean, :default => true
  end
end

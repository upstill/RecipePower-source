class ChangeDescriptionToText < ActiveRecord::Migration[4.2]
  def up
	change_column :feeds, :description, :text
	change_column :referents, :description, :text
  end
  def down
	change_column :feeds, :description, :string
	change_column :referents, :description, :string
  end
end

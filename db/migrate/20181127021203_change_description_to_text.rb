class ChangeDescriptionToText < ActiveRecord::Migration
  def up
	change_column :feeds, :description, :text
	change_column :referents, :description, :text
  end
  def down
	change_column :feeds, :description, :string
	change_column :referents, :description, :string
  end
end

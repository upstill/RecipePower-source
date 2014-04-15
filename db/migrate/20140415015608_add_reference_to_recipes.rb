class AddReferenceToRecipes < ActiveRecord::Migration
  def change
	add_column :recipes, :reference_id, :integer
	add_column :recipes, :picture_id, :integer
  end
end

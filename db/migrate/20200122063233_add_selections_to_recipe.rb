class AddSelectionsToRecipe < ActiveRecord::Migration[5.2]
  def change
    add_column :recipes, :anchor_path, :string
    add_column :recipes, :focus_path, :string
  end
end

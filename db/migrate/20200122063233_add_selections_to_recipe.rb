class AddSelectionsToRecipe < ActiveRecord::Migration[5.2]
  def change
    add_column :recipes, :anchorPath, :string
    add_column :recipes, :focusPath, :string
  end
end

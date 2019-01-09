class AddContentToRecipes < ActiveRecord::Migration[4.2]
  def change
    add_column :recipes, :content, :text
  end
end

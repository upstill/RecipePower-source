class AddContentToRecipes < ActiveRecord::Migration
  def change
    add_column :recipes, :content, :text
  end
end

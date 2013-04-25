class AddHrefToRecipes < ActiveRecord::Migration
  def change
    add_column :recipes, :href, :text
  end
end

class AddPictureIdToRecipes < ActiveRecord::Migration
  def change
    add_column :recipes, :picture_id, :integer
  end
end

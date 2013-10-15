class AddPicArToRecipesAndThumbnails < ActiveRecord::Migration
  def change
    add_column :recipes, :picAR, :float
    add_column :thumbnails, :picAR, :float
  end
end

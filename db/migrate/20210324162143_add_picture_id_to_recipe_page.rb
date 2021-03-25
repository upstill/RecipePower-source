class AddPictureIdToRecipePage < ActiveRecord::Migration[5.2]
  def change
    add_column :recipe_pages, :picture_id, :integer
    add_column :recipe_pages, :title, :string
  end
end

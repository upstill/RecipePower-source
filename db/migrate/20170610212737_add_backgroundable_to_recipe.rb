class AddBackgroundableToRecipe < ActiveRecord::Migration[4.2]
  def change
    add_column :sites, :dj_id, :integer
    add_column :sites, :status, :integer
    add_column :recipes, :dj_id, :integer
    add_column :recipes, :status, :integer
  end
end

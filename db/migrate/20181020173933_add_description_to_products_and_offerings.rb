class AddDescriptionToProductsAndOfferings < ActiveRecord::Migration
  def change
    add_column :products, :description, :text
    add_column :offerings, :description, :text
    add_column :offerings, :title, :text
  end
end

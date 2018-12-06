class AddDescriptionToProductsAndOfferings < ActiveRecord::Migration[4.2]
  def change
    add_column :products, :description, :text
    add_column :offerings, :description, :text
    add_column :offerings, :title, :text
  end
end

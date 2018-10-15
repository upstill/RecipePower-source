class AddBarcodeAndStringToProduct < ActiveRecord::Migration
  def change
    add_column :products, :barcode, :string # The barcode
    add_column :products, :bctype, :integer, default: 0 # The type (enum)
    add_column :products, :title, :string
  end
end

class AddBarcodeAndStringToProduct < ActiveRecord::Migration[4.2]
  def change
    add_column :products, :barcode, :string # The barcode
    add_column :products, :bctype, :integer, default: 0 # The type (enum)
    add_column :products, :title, :string
    add_column :products, :page_ref_id, :integer
  end
end

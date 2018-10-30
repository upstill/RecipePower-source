
class Product < ApplicationRecord
  include Taggable # Can be tagged using the Tagging model
  include Collectible
  include Referrable

  include Pagerefable
  pagerefable :url

  has_many :offerings, dependent: :destroy

  picable :picurl, :picture

  attr_accessible :barcode, :bctype, :title, :page_ref, :offerings, :picurl

  # barcode and bctype specify barcodes according to https://github.com/ankane/barkick
  enum bctype: [ :upc_a, :upc_e, :ean8 ]

  # Get the Barkick object for the product
  def gtin
    Barkick::GTIN.new barcode
  end

  # Here's us delegating all the barcode methods to Barkick::GTIN
  def method_missing(method, *args)
    return gtin.send(method, *args) if gtin.respond_to?(method)
    super
  end

end

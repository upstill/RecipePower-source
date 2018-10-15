
class Product < ActiveRecord::Base
  include Collectible

  include Pagerefable
  pagerefable :page_ref

  has_many :offerings

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

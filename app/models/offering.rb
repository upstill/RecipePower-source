# An Offering is a commercial instance of a Product
class Offering < ApplicationRecord

  # Link to the offering page
  include Pagerefable
  pagerefable :url

  # The product on offer
  belongs_to :product

  # attr_accessible :product, :page_ref

  # An offering gets its title from the product
  delegate :title, :to => :product

end

# An Offering is a commercial instance of a Product
class Offering < ActiveRecord::Base

  # Link to the offering page
  include Pagerefable
  pagerefable :page_ref

  # The product on offer
  has_one :product

  attr_accessible :product, :page_ref

  # An offering gets its title from the product
  delegate :title, :to => :product

end

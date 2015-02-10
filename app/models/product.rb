class Product < ActiveRecord::Base
  include Collectible
  picable :picurl, :picture
  # attr_accessible :title, :body
  has_many :links, :as => :entity
end

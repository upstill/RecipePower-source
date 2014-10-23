class Product < ActiveRecord::Base
  include Collectible
  # attr_accessible :title, :body
  has_many :links, :as => :entity
end

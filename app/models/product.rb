class Product < ActiveRecord::Base
  # attr_accessible :title, :body
  has_many :links, :as => :entity
end

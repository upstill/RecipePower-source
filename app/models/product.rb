class Product < ActiveRecord::Base
  include Taggable
  include Collectible
  include Picable
  picable :picurl, :picture
  # attr_accessible :title, :body
  has_many :links, :as => :entity
end

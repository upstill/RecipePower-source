class Reference < ActiveRecord::Base
  # attr_accessible :title, :body
  has_one :link, :as => :entity
end

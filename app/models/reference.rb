class Reference < ActiveRecord::Base
  include Linkable
  
  has_many :referments, :dependent => :destroy, :as => :referee, :inverse_of => :referee
  has_many :referents, :through => :referments
  # attr_accessible :title, :body
end

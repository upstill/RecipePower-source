class Tagset < ActiveRecord::Base
  attr_accessible :label, :tagrefs, :tags
  has_many :tagrefs
  has_many :tags, :through => :tagrefs

end

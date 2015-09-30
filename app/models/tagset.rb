class Tagset < ActiveRecord::Base
  include Taggable

  attr_accessible :title, :tagtype, :taggings

end

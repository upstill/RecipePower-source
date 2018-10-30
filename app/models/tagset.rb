class Tagset < ApplicationRecord
  include Taggable

  attr_accessible :title, :tagtype, :taggings

end

class Tagref < ActiveRecord::Base
  belongs_to :tag
  belongs_to :tagset
  attr_accessible :primary
end

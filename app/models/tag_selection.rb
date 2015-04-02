class TagSelection < ActiveRecord::Base
  belongs_to :tagset
  belongs_to :user
  belongs_to :tag
end

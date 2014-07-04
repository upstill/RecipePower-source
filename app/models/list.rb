class List < ActiveRecord::Base
  belongs_to :owner, class_name: "User"
  attr_accessible :owner, :ordering, :tag
  serialize :ordering
end

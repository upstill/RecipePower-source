class List < ActiveRecord::Base
  include Commentable
  commentable :notes

  belongs_to :owner, class_name: "User"   # The creator and default editor
  belongs_to :name_tag, class_name: "Tag"
  has_and_belongs_to_many :tags
  attr_accessible :owner, :ordering, :name_tag, :tags, :notes
  serialize :ordering
end

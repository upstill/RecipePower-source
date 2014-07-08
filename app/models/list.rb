class List < ActiveRecord::Base
  include Commentable
  commentable :notes
  include Taggable

  belongs_to :owner, class_name: "User"   # The creator and default editor
  belongs_to :name_tag, class_name: "Tag"
  has_and_belongs_to_many :tags
  attr_accessible :owner, :ordering, :name, :name_tag, :tags, :notes, :owner_id
  serialize :ordering

  # Using the name string, either find an existing list or create a new one FOR THE CURRENT USER
  def self.assert name, user, options={}
    puts "Asserting tag '#{name}' for user ##{user.id} (#{user.name})"
    tag = Tag.assert(name, tagtype: "List", userid: user.id)
    puts "...asserted with id #{tag.id}"
    List.where(owner_id: user.id, name_tag_id: tag.id).first || List.new(owner: user, name_tag: tag)
  end

  def name
    (name_tag && name_tag.name) || ""
  end

  def name=(new_name)
    puts "Setting name '#{new_name}'"
    (self.name_tag = Tag.assert(new_name, tagtype: "List", userid: owner.id)).name
  end
end

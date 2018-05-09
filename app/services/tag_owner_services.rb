class TagOwnerServices

  # Change the owned tag for each record from one tag to another, by id
  def self.change_tag from_id, to_id
    TagOwner.where(tag_id: from_id).each { |to| to.update_attribute :tag_id, to_id }
  end

  # Copy tag ownership from a tag with from_id to another tag with to_id
  def self.copy_tag from_id, to_id
    extant = TagOwner.where(tag_id: to_id).pluck :user_id # Get current owner ids for the target
    TagOwner.where(tag_id: from_id).each { |to|
      unless extant.include? to.user_id
        to = to.dup
        to.tag_id = to_id
        to.save
      end
    }
  end
end
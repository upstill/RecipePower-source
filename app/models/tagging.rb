
class Tagging < ActiveRecord::Base
  attr_accessible :user_id, :tag_id, :entity, :entity_id, :entity_type # :is_definition,
  
  belongs_to :tag
  belongs_to :tagger, :foreign_key => :user_id, :class_name => "User" # :user
  # A tagging may be applied to anything Taggable
  belongs_to :entity, :polymorphic => true
  
  before_save :ensure_unique

  scope :by_tag_id, -> (tag_id_or_ids) {
    where(tag_id: tag_id_or_ids)
  }

  scope :by_tagee_type, -> (classname) {
    where entity_type: classname.to_s
  }

  # From tagref: When saving a "new" Tag, make sure the tagging is unique
  def ensure_unique
  end
  
end

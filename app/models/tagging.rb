class Tagging < ActiveRecord::Base
  attr_accessible :user_id, :tag_id, :entity_id, :entity_type # :is_definition,
  
  belongs_to :tag
  belongs_to :user  
  # A tagging may be applied to a Recipe, Site, Feed, FeedEntry, User/Channel or Referent
  belongs_to :entity, :polymorphic => true
  
  before_save :ensure_unique

  # From tagref: When saving a "new" Tag, make sure the tagging is unique
  def ensure_unique
    puts "Ensuring uniqueness of tag #{self.tag_id.to_s} to taggable #{self.entity_id.to_s} for user #{self.user_id.to_s}"
  end
  
end

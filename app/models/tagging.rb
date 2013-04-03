class Tagging < ActiveRecord::Base
  attr_accessible :is_definition
  
  belongs_to :tag
  belongs_to :user  
  # A tagging may be applied to a Recipe, Site, Feed, FeedEntry, User/Channel or Referent
  belongs_to :entity, :polymorphic => true
  
  before_save :ensure_unique
  after_save :notify_referents

  # From tagref: When saving a "new" Tag, make sure the tagging is unique
  def ensure_unique
    puts "Ensuring uniqueness of tag #{self.tag_id.to_s} to taggable #{self.entity_id.to_s} for user #{self.user_id.to_s}"
  end

  def notify_referents
    self.tag.referents.each { |ref| ref.notice_resource self.entity }
  end
  
end

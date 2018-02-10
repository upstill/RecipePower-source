
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

  # Return a scope on the Tagging table for the unfiltered contents of the list
  scope :list_scope, -> (list, viewerid=nil) {
    # We get everything tagged either directly by the list tag, or indirectly via
    # the included tags, EXCEPT for other users' tags using the list's tag
    tag_ids = [list.name_tag_id]
    tagger_id_or_ids = [list.owner_id, viewerid].compact.uniq
    whereclause = tagger_id_or_ids.count > 1 ?
        "(taggings.user_id in (#{tagger_id_or_ids.join ','}))" :
        "(taggings.user_id = #{tagger_id_or_ids = tagger_id_or_ids.first})"
    whereclause << " or (taggings.tag_id != #{list.name_tag_id})"
    # If the pullin flag is on, we also include material tagged with the list's included_tags
    # BY ITS OWNER
    if list.pullin
      list.included_tags.each do |it|
        tag_ids << it.id
        tag_ids += TagServices.new(it).similar_ids
      end
      whereclause = "(#{whereclause}) and not (taggings.entity_type = 'List' and taggings.entity_id = #{list.id})"
    end
    where(tag_id: (tag_ids.count>1 ? tag_ids : tag_ids.first)).where whereclause
  }

  # From tagref: When saving a "new" Tag, make sure the tagging is unique
  def ensure_unique
  end
  
end

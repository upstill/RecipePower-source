module Taggable
  extend ActiveSupport::Concern

  included do
    attr_accessible :tag_tokens, :current_user
    has_many :taggings, :as => :entity, :dependent => :destroy
    # has_many :tags, :through => :taggings
    has_many :taggers, :through => :taggings, :class_name => "User"
    attr_accessor :current_user
  end

  def tags(uid=nil)
    uid ||= current_user
    Tag.where(id: tag_ids(uid))
  end
  
  def tags=(tags)
    # Ensure that the user's tags are all and only those in nids
    self.tag_ids=tags.map(&:id)
  end

  def tag_ids(uid=nil)
    uid ||= current_user
    taggings.where(:user_id => uid).map(&:tag_id)
  end
  
  # Set the tag ids associated with the current user
  def tag_ids=(nids)
    # Ensure that the user's tags are all and only those in nids
    oids = tag_ids current_user
    to_add = nids - oids
    to_remove = oids - nids
    # Add new tags as necessary
    to_add.each { |tagid| Tagging.create(user_id: current_user, tag_id: tagid, entity_id: id, entity_type: self.class.name) }
    # Remove tags as nec.
    to_remove.each { |tagid| Tagging.where(user_id: current_user, tag_id: tagid, entity_id: id, entity_type: self.class.name).map(&:destroy) } # each { |tg| tg.destroy } }
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids
  def tag_tokens=(idstring)
    # The list may contain new terms, passed in single quotes
    self.tags = idstring.split(",").map { |e| 
      if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags
        Tag.find e.to_i
      else
        e.sub!(/^\'(.*)\'$/, '\1') # Strip out enclosing quotes
        Tag.strmatch(e, userid: current_user, assert: true)[0] # Match or assert the string
      end
    }.compact.uniq
  end
end

module Taggable
  extend ActiveSupport::Concern

  included do
    attr_accessible :tag_tokens, :current_user
    has_many :taggings, :as => :entity, :dependent => :destroy
    has_many :tags, :through => :taggings
    has_many :taggers, :through => :taggings, :class_name => "User"
  end

  def tag_tokens(uid=nil)
    uid ||= current_user
    taggings.where(:user_id => uid, :entity_id => id, :entity_type => self.class).map(&:tag_id)
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids
  def tag_tokens=(idstring, uid=nil)
    uid ||= current_user
    # The list may contain new terms, passed in single quotes
    tagset = ids.split(",").map { |e| 
      if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags
        Tag.find e.to_i
      else
        e.sub!(/^\'(.*)\'$/, '\1') # Strip out enclosing quotes
        Tag.strmatch(e, userid: uid, assert: true)[0] # Match or assert the string
      end
    }.compact.uniq
    utags = (tagset, uid)
  end
  
  # Get the tag ids associated with the given user
  def utags(uid)
    Tagging.where(:user_id => uid, :entity_id => id, :entity_type => self.class).map(&:id)
  end
  
  # Set the tag ids associated with the given user
  def utags=(nids, uid)
    # Ensure that the user's tags are all and only those in utags
    oids = utags uid
    # Add new tags as necessary
    (nids - oids).each { |tagid| Tagging.create(user_id: current_user, tag_id: tagid, entity_id: id, entity_type: self.class) }
    # Remove tags as nec.
    (oids - nids).each { |tagid| Tagging.where(user_id: current_user, tag_id: tagid, entity_id: id, entity_type: self.class).each.destroy }
  end
end

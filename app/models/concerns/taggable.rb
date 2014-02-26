require 'token_input.rb'

module Taggable
  extend ActiveSupport::Concern

  included do
    attr_accessible :tag_tokens
    has_many :taggings, :as => :entity, :dependent => :destroy
    # has_many :tags, :through => :taggings
    has_many :taggers, :through => :taggings, :class_name => "User"
    attr_accessor :current_user
    attr_reader :tag_tokens
  end
  
  # The tags will be owned by the declared user. Classes can override this method
  # as desired
  def tag_owner
    current_user || User.super_id
  end

  def tagstxt
    @tagstxt ||= ""
  end
  alias_method :tagtxt, :tagstxt

  def tagstxt= tt
    @tagstxt = tt
  end
  alias_method :"tagtxt=", :"tagstxt="

  # Fetch the tags associated with the entity
  def tags options = {}
    if tt = options.delete(:tag_type)
      Tag.where id: tag_ids(options), tagtype: Tag.typenum(tt)
    else
      Tag.where id: tag_ids(options)
    end

  end
  alias_method :tag, :tags

  # Fetch the ids of the tags associated with the entity
  def tag_ids options={}
    taggings.where(:user_id => (options[:owner_id] || tag_owner)).map &:tag_id
  end
  alias_method :tag_id, :tag_ids

  # Set the tags associated with the entity
  def tags= tags
    # Ensure that the user's tags are all and only those given
    self.tag_ids=tags.map(&:id)
  end
  alias_method :"tag=", :"tags="

  # Set the tag ids associated with the current user
  def tag_ids= nids
    # Ensure that the user's tags are all and only those in nids
    oids = tag_ids
    to_add = nids - oids
    to_remove = oids - nids
    # Add new tags as necessary
    to_add.each { |tagid| Tagging.create(user_id: tag_owner, tag_id: tagid, entity_id: id, entity_type: self.class.name) }
    # Remove tags as nec.
    to_remove.each { |tagid| Tagging.where(user_id: tag_owner, tag_id: tagid, entity_id: id, entity_type: self.class.name).map(&:destroy) } # each { |tg| tg.destroy } }
  end
  alias_method :"tag_id=", :"tag_ids="

  # Associate a tag with this entity in the domain of the given user (or the current user if not given)
  def tag_with tag
    Tagging.create(user_id: tag_owner, tag_id: tag.id, entity_id: id, entity_type: self.class.name) unless tag_ids(uid).include? tag.id
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids
  def tag_tokens=(idstring)
    self.tags =
    TokenInput.parse_tokens(idstring) do |token| # parse_tokens analyzes each token in the list as either integer or string
      case token
      when Fixnum
        Tag.find token
      when String
        Tag.strmatch(token, userid: tag_owner, assert: true)[0] # Match or assert the string
      end
    end
=begin
This is the old functionality, now moved to token_input.rb
    # The list may contain new terms, passed in single quotes
    self.tags = idstring.split(",").map { |e| 
      if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags
        Tag.find e.to_i
      else
        e.sub!(/^\'(.*)\'$/, '\1') # Strip out enclosing quotes
        Tag.strmatch(token, userid: tag_owner, assert: true)[0] # Match or assert the string
      end
    }.compact.uniq
=end
  end
  alias_method :"tag_token=", :"tag_tokens="

  # Declare a data structure suitable for passing to RP.tagger.init
  def tag_data typed=false
    attribs = tags.collect { |tag| { id: tag.id, name: tag.typedname(typed) } }
    { :pre => attribs, :hint => "Type your tag(s) for the recipe here" }.to_json
  end
end

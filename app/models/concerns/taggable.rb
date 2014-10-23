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

    Tag.taggable self
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

  # Fetch the tags associated with the entity, possibly with constraints of userid and type
  def tags opts = {}
    options = opts.clone # Don't muck with the options
    if tt = options.delete(:tagtype)
      Tag.where id: tag_ids(options), tagtype: Tag.typenum(tt)
    elsif nt = options.delete(:tagtype_x)
      tags = Tag.where.not tagtype: Tag.typenum(nt)
      tags.where( id: tag_ids(options))
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
    if nids.is_a? Hash
      owner = nids[:owner_id]
      nids = nids[:tag_ids]
    else
      owner = tag_owner
    end
    # Ensure that the user's tags are all and only those in nids
    oids = tag_ids owner_id: owner
    to_add = nids - oids
    to_remove = oids - nids
    # Add new tags as necessary
    to_add.each { |tagid| Tagging.create(user_id: owner, tag_id: tagid, entity_id: id, entity_type: self.class.name) }
    # Remove tags as nec.
    to_remove.each { |tagid| Tagging.where(user_id: owner, tag_id: tagid, entity_id: id, entity_type: self.class.name).map(&:destroy) } # each { |tg| tg.destroy } }
  end
  alias_method :"tag_id=", :"tag_ids="

  # Associate a tag with this entity in the domain of the given user (or the tag's current owner if not given)
  def tag_with tag, who=nil
    who ||= tag_owner
    Tagging.create(user_id: who, tag_id: tag.id, entity_id: id, entity_type: self.class.name) unless tag_ids(owner_id: who).include? tag.id
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids. To apply constraints, the token string
  # is passed as a member of a hash.
  def tag_tokens= tokenstr
    if tokenstr.is_a? Hash
      constraints = tokenstr.clone
      tokenstr = constraints.delete :tokenstr
    else
      constraints = {}
    end
    constraints[:userid] = tag_owner
    constraints[:assert] = true
    asserted =
    TokenInput.parse_tokens(tokenstr) do |token| # parse_tokens analyzes each token in the list as either integer or string
      case token
      when Fixnum
        Tag.find token
      when String
        Tag.strmatch(token, constraints)[0] # Match or assert the string
      end
    end
    # If we're asserting tokens OF A PARTICULAR TYPE(S), we need to leave the other types untouched.
    # We do this by augmenting the declared set appropriately
    if constraints[:tagtype] # Restricting to certain types: don't touch the others
      constraints[:tagtype_x] = constraints.delete :tagtype
      self.tags = asserted + tags(constraints)
    elsif constraints[:tagtype_x] # Excluding certain types => don't touch them
      constraints[:tagtype] = constraints.delete :tagtype_x
      self.tags = asserted + tags(constraints)
    else
      self.tags = asserted
    end
  end
  alias_method :"tag_token=", :"tag_tokens="

  # Declare a data structure suitable for passing to RP.tagger.init
  def tag_data options={}
    data = { :hint => options.delete(:hint) || "Type your tag(s) here" }
    data[:pre] = tags(options).collect { |tag| { id: tag.id, name: tag.typedname(options[:showtype]) } }
    data[:query] = options.slice :verbose, :showtype
    data[:query][:tagtype] = Tag.typenum(options[:tagtype]) if options[:tagtype]
    data[:query][:tagtype_x] = Tag.typenum(options[:tagtype_x]) if options[:tagtype_x]
    data.to_json
  end
end

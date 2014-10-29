require 'token_input.rb'

module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, :as => :entity, :dependent => :destroy
    has_many :tags, :through => :taggings
    has_many :taggers, :through => :taggings, :class_name => "User"
    attr_accessor :tagging_user_id, :tagging_tags, :tagging_tokens
    attr_accessible :tagging_user_id, :tagging_tags, :tagging_tokens

    Tag.taggable self
  end

  # Define an editable field of taggings by the current user on the entity
  def define_user_taggings user_id
    self.tagging_user_id = user_id
    self.tagging_tags = tags_by_user user_id
  end

  # Ensure that the user taggings get associated with the entity
  # Interpret the set of tag tokens into a list of tags ready to turn into taggings
  def accept_user_taggings
    return unless tagging_user_id
    asserted = # Map the elements of the token string to tags, whether existing or new
        TokenInput.parse_tokens(tagging_tokens) do |token| # parse_tokens analyzes each token in the list as either integer or string
          case token
            when Fixnum
              Tag.find token
            when String
              Tag.strmatch(token, userid: tagging_user_id, assert: true)[0] # Match or assert the string
          end
        end
    set_tags tagging_user_id, asserted
  end

  def tags_visible_to uid=nil, opts = {}
    uid = uid.to_i if uid.is_a? String
    uid, opts = nil, uid if uid.is_a? Hash
    tags_by_user uid, opts
  end

  # Associate a tag with this entity in the domain of the given user (or the tag's current owner if not given)
  def tag_with tag, who
    unless get_tag_ids(who).include? tag.id
      Tagging.create(user_id: who, tag_id: tag.id, entity_id: id, entity_type: self.class.name)
    end
  end

  # Declare a data structure suitable for passing to RP.tagger.init
  def tag_data options={}
    data = { :hint => options.delete(:hint) || "Type your tag(s) here" }
    data[:pre] = tags(options).collect { |tag| { id: tag.id, name: tag.typedname(options[:showtype]) } }
    data[:query] = options.slice :verbose, :showtype
    data[:query][:tagtype] = Tag.typenum(options[:tagtype]) if options[:tagtype]
    data[:query][:tagtype_x] = Tag.typenum(options[:tagtype_x]) if options[:tagtype_x]
    data.to_json
  end

protected

  # Fetch the tags associated with the entity, possibly with constraints of userid and type
  def tags_by_user uid, opts = {}
    uid = uid.to_i if uid.is_a? String
    uid, opts = nil, uid if uid.is_a? Hash
    tagscope = Tag.unscoped
    tagscope = tagscope.where(tagtype: Tag.typenum(opts[:tagtype])) if opts[:tagtype]
    tagscope = tagscope.where.not(tagtype: Tag.typenum(opts[:tagtype_x])) if opts[:tagtype_x]
    # Tag.where.not(tagtype: Tag.typenum(nt)).where id: get_tag_ids(uid, options)
    tagging_constraints = { entity: self }
    # tagging_constraints[:user_id] = uid if uid
    tagscope.joins(:taggings).where taggings: tagging_constraints
  end

  # Set the tags associated with the entity
  def set_tags uid, tags=nil
    # May call without a uid, which defaults to super
    uid = uid.to_i if uid.is_a? String
    uid, tags = User.super_id, uid unless tags
    # Ensure that the user's tags are all and only those given
    set_tag_ids uid, tags.map(&:id)
  end

  # Set the tag ids associated with the given user
  def set_tag_ids uid, nids
    # Ensure that the user's tags are all and only those in nids
    oids = get_tag_ids uid
    to_add = nids - oids
    to_remove = oids - nids
    # Add new tags as necessary
    to_add.each { |tagid| Tagging.create(user_id: uid, tag_id: tagid, entity_id: id, entity_type: self.class.name) }
    # Remove tags as nec.
    to_remove.each { |tagid| Tagging.where(user_id: uid, tag_id: tagid, entity_id: id, entity_type: self.class.name).map(&:destroy) } # each { |tg| tg.destroy } }
  end

  # Fetch the ids of the tags associated with the entity
  def get_tag_ids uid, options={}
    uid = uid.to_i if uid.is_a? String
    uid, options = nil, uid if uid.is_a? Hash
    scope = uid ? taggings : taggings.where(:user_id => uid)
    scope.map &:tag_id
  end

end

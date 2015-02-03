require 'token_input.rb'

module Taggable
  extend ActiveSupport::Concern

  included do
    # When the record is saved, save its affiliated tagging info
    before_save do
      if @tagging_user_id && @tagging_tag_tokens # May not actually be editing tags
        # Map the elements of the token string to tags, whether existing or new
        set_tag_ids TokenInput.parse_tokens(@tagging_tag_tokens) { |token| # parse_tokens analyzes each token in the list as either integer or string
                      token.is_a?(Fixnum) ? token : Tag.strmatch(token, userid: @tagging_user_id, assert: true)[0].id # Match or assert the string
                    }
      end
    end

    has_many :taggings, :as => :entity, :dependent => :destroy
    has_many :tags, -> { uniq }, :through => :taggings
    has_many :taggers, -> { uniq }, :through => :taggings, :class_name => "User"
    attr_accessor :tagging_user_id, :tagging_tag_tokens # Only gets written externally; internally accessed with instance variable
    attr_accessible :tagging_user_id, :tagging_tag_tokens # For the benefit of update_attributes

    Tag.taggable self
  end

  # Define an editable field of taggings by the current user on the entity
  def uid= user_id
    @tagging_user_id = user_id.to_i
    super if defined? super
  end

  # Allow the given user to see tags applied by themselves and super
  def visible_tags user_id = nil, options={}
    if user_id.is_a?(Hash)
      user_id, options = nil, user_id
    end
    user_id ||= @tagging_user_id
    taggers = [User.super_id]
    taggers << user_id if user_id
    filtered_tags options.merge(user_id: taggers) # Allowing for an array of uids
  end

  # Return the editable tags, i.e. not channels, collections, or lists
  def tagging_tags
    filtered_tags(:tagtype_x => [11, :Collection, :List])
  end

  # Provide the tags of appropriate types for the user identified by @tagging_user_id
  def tagging_tag_data
    tagging_tags.map(&:attributes).to_json
  end

  # Associate a tag with this entity in the domain of the given user (or the tag's current owner if not given)
  def tag_with tag_or_id, uid=nil
    assert_tagging tag_or_id, (uid || @tagging_user_id)
  end

  def shed_tag tag_or_id, uid=nil
    refute_tagging tag_or_id, (uid || @tagging_user_id)
  end

  # One collectible is being merged into another => transfer taggings
  def absorb other
    # Take taggings from the other taggable
    other.taggings.map { |tagging| tag_with tagging.tag, tagging.user_id }
    super if defined? super
  end

=begin Possibly called procedurally?
  # Declare a data structure suitable for passing to RP.tagger.init
  def tag_editing_data options={}
    options[:tagtype_x] = [11, :Collection, :List]
    data = { :hint => options.delete(:hint) || "Type your tag(s) here" }
    data[:pre] = filtered_tags(options).collect { |tag| { id: tag.id, name: tag.typedname(options[:showtype]) } }
    data[:query] = options.slice :verbose, :showtype
    data[:query][:tagtype] = Tag.typenum(options[:tagtype]) if options[:tagtype]
    data[:query][:tagtype_x] = Tag.typenum(options[:tagtype_x]) if options[:tagtype_x]
    data.to_json
  end

  def tag_data uid, options={}
    data = { :hint => options.delete(:hint) || "Type your tag(s) here" }
    data[:pre] = filtered_tags(options).collect { |tag| { id: tag.id, name: tag.typedname(options[:showtype]) } }
    data[:query] = options.slice :verbose, :showtype
    data[:query][:tagtype] = Tag.typenum(options[:tagtype]) if options[:tagtype]
    data[:query][:tagtype_x] = Tag.typenum(options[:tagtype_x]) if options[:tagtype_x]
    data.to_json
  end
=end

  protected

  # Fetch the tags associated with the entity, with various optional constraints (including userid via @taggable_user_id)
  # Options:
  # :tagtype: one or more types to be applied
  # :tagtype_x: one or more types to be ignored
  # :user_id: one or more users to whose taggings the results will be restricted
  def filtered_tags opts = {}
    tagscope = Tag.unscoped
    tagscope = tagscope.where(tagtype: Tag.typenum(opts[:tagtype])) if opts[:tagtype]
    tagscope = tagscope.where.not(tagtype: Tag.typenum(opts[:tagtype_x])) if opts[:tagtype_x]
    tagging_constraints = opts.slice(:user_id).merge entity: self
    tagging_constraints[:user_id] ||= @taggable_user_id if @taggable_user_id
    tagscope.joins(:taggings).where(taggings: tagging_constraints).uniq
  end

  # Set the tag ids associated with the given user
  def set_tag_ids nids
    # Ensure that the user's tags are all and only those in nids
    oids = tagging_tags.pluck :id

    # Add new tags as necessary
    (nids - oids).each { |tagid| assert_tagging tagid, @tagging_user_id }

    # Remove tags as nec.
    (oids - nids).each { |tagid| refute_tagging tagid, @tagging_user_id }
  end

  def assert_tagging tag_or_id, uid
    Tagging.find_or_create_by user_id: uid,
                              tag_id: (tag_or_id.is_a?(Fixnum) ? tag_or_id : tag_or_id.id),
                              entity: self
  end

  def refute_tagging tag_or_id, uid
    Tagging.where(user_id: uid,
                  tag_id: (tag_or_id.is_a?(Fixnum) ? tag_or_id : tag_or_id.id),
                  entity: self).map(&:destroy)
  end
end

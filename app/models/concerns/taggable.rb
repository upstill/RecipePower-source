require 'token_input.rb'

module Taggable
  extend ActiveSupport::Concern

  module ClassMethods

    # Provide the list of parameters that taggables may accept
    def mass_assignable_attributes keys=[]
      [   :tagging_tag_tokens, :tagging_list_tokens,
          :editable_tag_tokens, :editable_misc_tag_tokens,
          :editable_author_tag_tokens, :editable_dish_tag_tokens,
          :editable_genre_tag_tokens, :editable_ingredient_tag_tokens,
          :editable_tool_tag_tokens, :editable_process_tag_tokens,
          :editable_occasion_tag_tokens, :editable_source_tag_tokens,
          :editable_course_tag_tokens, :editable_diet_tag_tokens ] +
          (defined?(super) ? super : [])
    end

  end

  included do

    # When the record is saved, save its affiliated tagging info
=begin
    before_save do
      if @tagging_user_id
        if @tagging_list_tokens
          # Map the elements of the token string to tags, whether existing or new
          ListServices.associate(
              self,
              TokenInput.parse_tokens(@tagging_list_tokens) { |token| # parse_tokens analyzes each token in the list as either integer or string
                token.is_a?(Fixnum) ?
                    Tag.find(token) :
                    Tag.strmatch(token, userid: @tagging_user_id, tagtype: :List, assert: true)[0] # Match or assert the tag
              },
              @tagging_user_id)
        end
      end
    end
=end

    has_many :taggings, :as => :entity, :dependent => :destroy
    has_many :tags, -> { uniq }, :through => :taggings
    has_many :taggers, -> { uniq }, :through => :taggings, :class_name => 'User'

    # Scope for objects tagged by a given tag, as visible to the given viewer
    scope :tagged_by, -> (tag_or_tags_or_id_or_ids, viewer_id_or_ids=nil) {
      ids = [tag_or_tags_or_id_or_ids].flatten.map { |tag_or_id| tag_or_id.is_a?(Fixnum) ? tag_or_id : tag_or_id.id }
      joins(:taggings).where( taggings: { user_id: viewer_id_or_ids.if_present, tag_id: ids }.compact )
    }

    # TODO: This shouldn't be public: should be using current_user outside the object context
    attr_reader :tagging_user_id
=begin
    # attr_accessible :tagging_user_id, :tagging_tag_tokens, :tagging_list_tokens, # For the benefit of update_attributes
                    :editable_tag_tokens, :editable_misc_tag_tokens,
                    :editable_author_tag_tokens, :editable_dish_tag_tokens,
                    :editable_genre_tag_tokens, :editable_ingredient_tag_tokens,
                    :editable_tool_tag_tokens, :editable_process_tag_tokens,
                    :editable_occasion_tag_tokens, :editable_source_tag_tokens,
                    :editable_course_tag_tokens, :editable_diet_tag_tokens
=end
                    Tag.taggable self
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def tagging_list_tokens= tokenlist_str
    ListServices.associate(
        self,
        TokenInput.parse_tokens(tokenlist_str) { |token| # parse_tokens analyzes each token in the list as either integer or string
          token.is_a?(Fixnum) ?
              Tag.find(token) :
              Tag.strmatch(token, userid: @tagging_user_id, tagtype: :List, assert: true)[0] # Match or assert the tag
        },
        @tagging_user_id)
  end

=begin
  # NB: gleaning the appropriate list tokens is the responsibility of UserDecorator#list_tags
  def tagging_list_tokens
    x=3
  end
=end

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
    taggers = [User.super_id, (user_id || @tagging_user_id)].compact
    filtered_tags options.merge(user_id: taggers) # Allowing for an array of uids
  end

  def tagging_tags_of_type type_or_types
    filtered_tags tagtype: type_or_types
  end

  # Return the editable tags for the current user, i.e. not lists
  def tagging_tags options={}
    filtered_tags options.merge(
                      :tagtype_x => [options[:tagtype_x], :List].flatten.compact
                  )
  end

  # We can't get here if we're not Pagerefable
  def adopt_gleaning
    if page_ref.gleaning && (tagstrings = page_ref.gleaning.results_for('Tags'))
      ts = TaggingServices.new self
      tagstrings.each { |tagstring|
        tagstring.split(',').map(&:strip).each { |tagname| ts.tag_with tagname, User.super_id }
      }
    end
    super if defined?(super)
  end

=begin
  # Provide the tags of appropriate types for the user identified by @tagging_user_id
  def tagging_tag_data options={}
    tagging_tags(options).map(&:attributes).to_json
  end
=end

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

=begin
  def incoming_attributes keys
    token_attributes = keys.select { |key| key[/^(visible_|editable_|locked_)?((not?_)?[^_]*_)*(tags|tag_tokens)$/] }.reverse.map &:to_sym
    # self.class_eval { attr_accessible *token_attributes }
  end
=end

  # Here we corral methods of the form {visible,editable,locked}[_type]_{tags,tag_tokens}[=]
  # visible means the user can see
  # editable means the user can edit
  # locked means the user can see but not edit
  def method_missing namesym, *args
    namestr = namesym.to_s
    is_assignment = namestr.sub!(/=$/, '')
    substrs = namestr.split '_'
    return super unless case substrs.pop
                        when 'tags'
                          substrs.present?
                        when 'tokens'
                          (tokens = substrs.pop) == 'tag' && substrs.present?
                        end
    begin
      filter_options = {}
      # The tags of the entity are categorized as follows:
      # 'editable' tags are exactly those which the viewer (current user) applied
      # 'visible' are all tags the user can see (those of the user and all their friends)
      # 'locked' are visible tags that the user CANNOT edit, i.e. visible - editable
      case (substrs.shift if %w{ visible editable locked }.include? substrs.first)
      when 'visible'
        filter_options[:user_id] = (@tagging_user_id ? UserRelation.followee_ids_of(@tagging_user_id) : []) +
            [User.super_id, @tagging_user_id].compact
      when 'editable'
        filter_options[:user_id] = @tagging_user_id if @tagging_user_id
      when 'locked'
        followee_ids = (@tagging_user_id ? UserRelation.followee_ids_of(@tagging_user_id) : []) << User.super_id
        filter_options[:user_id] = followee_ids.reject { |id| id == @tagging_user_id }
      end
      tagtype, tagtype_x = [], [:Question, :List]
      while type = substrs.shift do
        if type == 'not' || type == 'no'
          tagtype_x << substrs.shift.capitalize.to_sym
        else
          tagtype << type.capitalize.to_sym
        end
      end
      if tagtype.present?
        filter_options[:tagtype] = tagtype.uniq
      else # NB: we only apply exclusions if there is no positive
        filter_options[:tagtype_x] = tagtype_x.uniq
      end
    rescue Exception => e
      puts "Parse of #{namesym} failed: #{e}"
    end
    if is_assignment && @tagging_user_id
      nids =
          if tokens
            # Map the elements of the token string to tags, whether existing or new
            TokenInput.parse_tokens(args.first) {|token| # parse_tokens analyzes each token in the list as either integer or string
              token.is_a?(Fixnum) ? token : Tag.strmatch(token, filter_options.merge(assert: true))[0].id # Match or assert the string
            }
          else
            args.first.map &:id
          end

      # By a remarkable coincidence, the taglist as currently defined is fetched by the corresponding 'get' method
      oids = self.method_missing((namestr.sub /tag_tokens$/, 'tags').to_sym).pluck :id

      # Add new tags as necessary
      (nids - oids).each {|tagid| assert_tagging tagid, @tagging_user_id}

      # Remove tags as nec.
      (oids - nids).each {|tagid| refute_tagging tagid, @tagging_user_id}
    end
    logger.debug filter_options
    filtered_tags filter_options
  end

  # Fetch the tags associated with the entity, with various optional constraints (including userid via @tagging_user_id)
  # Options:
  # :tagtype: one or more types to be applied
  # :tagtype_x: one or more types to be ignored
  # :user_id: one or more users to whose taggings the results will be restricted
  def filtered_tags opts = {}
    tagscope = Tag.unscoped
    tagscope = tagscope.where(tagtype: Tag.typenum(opts[:tagtype])) if opts[:tagtype]
    tagscope = tagscope.where.not(tagtype: Tag.typenum(opts[:tagtype_x])) if opts[:tagtype_x]
    tagging_constraints = opts.slice(:user_id).merge entity: self
    # tagging_constraints[:user_id] ||= @tagging_user_id if @tagging_user_id
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

  # Manage taggings of a given user
  def assert_tagging tag_or_id, uid
    Tagging.find_or_create_by user_id: uid,
                              tag_id: (tag_or_id.is_a?(Fixnum) ? tag_or_id : tag_or_id.id),
                              entity: self
  end

  def refute_tagging tag_or_id, uid=nil
    scope = taggings.where tag_id: (tag_or_id.is_a?(Fixnum) ? tag_or_id : tag_or_id.id)
    scope = scope.where(user_id: uid) if uid
    scope.map &:destroy
  end
end

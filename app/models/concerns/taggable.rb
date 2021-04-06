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

    has_many :taggings, :as => :entity, :dependent => :destroy
    has_many :tags, -> { distinct }, :through => :taggings
    has_many :taggers, -> { distinct }, :through => :taggings, :class_name => 'User'

    # Scope for objects tagged by a given tag, as visible to the given viewer
    scope :tagged_by, -> (tag_or_tags_or_id_or_ids, viewer_id_or_ids=nil) {
      ids = [tag_or_tags_or_id_or_ids].flatten.map { |tag_or_id| tag_or_id.is_a?(Integer) ? tag_or_id : tag_or_id.id }
      joins(:taggings).where( taggings: { user_id: viewer_id_or_ids.if_present, tag_id: ids }.compact )
    }

    Tag.taggable self
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def tagging_list_tokens= tokenlist_str
    ListServices.associate( # Assign tags to the taggable entity, relative to the current user
        self,
        TokenInput.parse_tokens(tokenlist_str) { |token| # parse_tokens analyzes each token in the list as either integer or string
          token.is_a?(Integer) ?
              Tag.find(token) :
              Tag.strmatch(token, userid: User.current_id, tagtype: :List, assert: true)[0] # Match or assert the tag
        }
    )
  end

  def tagging_tags_of_type type_or_types
    filtered_tags tagtype: type_or_types
  end

  # Associate a tag with this entity in the domain of the given user (or the tag's current owner if not given)
  def tag_with tag_or_id, user_id=User.current_id
    assert_tagging tag_or_id, user_id
  end

  def shed_tag tag_or_id, user_id=User.current_id
    refute_tagging tag_or_id, user_id
  end

  # One collectible is being merged into another => transfer taggings
  def absorb other
    # Take taggings from the other taggable
    other.taggings.map { |tagging| tag_with tagging.tag, tagging.user_id }
    super if defined? super
  end

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
        filter_options[:user_id] = (User.current ? User.current.followee_ids : []) +
            [User.super_id, User.current_id].compact
      when 'editable'
        filter_options[:user_id] = User.current_id if User.current_id
      when 'locked'
        followee_ids = (User.current ? User.current.followee_ids : []) << User.super_id
        filter_options[:user_id] = followee_ids - [ User.current_id ]
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
      logger.debug "Parse of #{namesym} failed: #{e}"
    end
    if is_assignment && User.current_id
      nids =
          if tokens
            # Map the elements of the token string to tags, whether existing or new
            TokenInput.parse_tokens(args.first) {|token| # parse_tokens analyzes each token in the list as either integer or string
              token.is_a?(Integer) ?
                  token :
                  Tag.strmatch(token, filter_options.merge(assert: true, userid: User.current_id))[0].id # Match or assert the string
            }
          else
            args.first.map &:id
          end

      # By a remarkable coincidence, the taglist as currently defined is fetched by the corresponding 'get' method
      oids = self.method_missing((namestr.sub /tag_tokens$/, 'tags').to_sym).pluck :id

      # Add new tags as necessary
      (nids - oids).each {|tagid| assert_tagging tagid }

      # Remove tags as nec.
      (oids - nids).each {|tagid| refute_tagging tagid }
    end
    logger.debug filter_options
    filtered_tags filter_options
  end

  # Fetch the tags associated with the entity, with various optional constraints (including userid via User.current_id)
  # Options:
  # :tagtype: one or more types to be applied
  # :tagtype_x: one or more types to be ignored
  # :user_id: one or more users to whose taggings the results will be restricted
  def filtered_tags opts = {}
    tagscope = Tag.unscoped
    tagscope = tagscope.where(tagtype: Tag.typenum(opts[:tagtype])) if opts[:tagtype]
    tagscope = tagscope.where.not(tagtype: Tag.typenum(opts[:tagtype_x])) if opts[:tagtype_x]
    tagging_constraints = opts.slice(:user_id).merge entity: self
    tagscope.joins(:taggings).where(taggings: tagging_constraints).distinct
  end

  # Ensure that the user's tags are all and only those in new_tag_ids
  def set_tag_ids user_id, new_tag_ids
    old_tag_ids = taggings.where(user_id: user_id).pluck :tag_id

    # Add new tags as necessary
    (new_tag_ids - old_tag_ids).each { |tagid| assert_tagging tagid, user_id }

    # Remove tags as nec.
    (old_tag_ids - new_tag_ids).each { |tagid| refute_tagging tagid, user_id }
  end

  # Manage taggings of a given user
  def assert_tagging tag_or_id, user_id=User.current_id
    return unless user_id
    tag_id = tag_or_id.is_a?(Integer) ? tag_or_id : tag_or_id.id
    if persisted?
      return if taggings.exists? user_id: user_id, tag_id: tag_id
      taggings.create user_id: user_id, tag_id: tag_id
    else
      return if taggings.any? { |tagging| tagging.tag_id == tag_id && tagging.user_id == user_id }
      taggings.build user_id: user_id, tag_id: tag_id
    end
  end

  def refute_tagging tag_or_id, user_id=User.current_id
    return unless user_id
    tag_id = tag_or_id.is_a?(Integer) ? tag_or_id : tag_or_id.id
=begin
    scope = taggings.where tag_id: tag_id
    scope = scope.where(user_id: user_id) if user_id
    scope.map &:destroy
=end
    extant = persisted? ?
                 taggings.where(user_id: user_id, tag_id: tag_id).to_a :
                 taggings.keep_if { |tagging| tagging.tag_id == tag_id && tagging.user_id == user_id }
    taggings.destroy *extant
  end


end

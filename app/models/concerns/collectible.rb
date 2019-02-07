module Collectible
  extend ActiveSupport::Concern
  include Voteable
  include Picable

  module ClassMethods

    def mass_assignable_attributes keys=[]
      [ :collectible_comment, :collectible_private ] +
          (defined?(super) ? super : [])
    end
  end

  included do

    # We keep a cache of rcprefs that have been accessed by a user, to
    # 1) speed up subsequent accesses
    # 2) ensure that changes to refs are saved when the entity is saved.
    # NB: this is because ActiveRecord doesn't keep a record of individual members of an association,
    # and so can't :autosave them
    before_save do
      if @cached_refs
        # We want to save rcprefs that need to be saved because they're not part of an association
        # the sign of which is they're persisted and have an entity_id
        # We save the cached refs that are newly created, under the assumption that
        @cached_refs.values.compact.each { |ref| puts "Saving Rcpref##{ref.id}" ; ref.save } # unless ref.persisted? && ref.entity_id }
        @cached_refs = {}
      end
    end

    def reload
      @cached_refs = {}
      super
    end

    # We seek to preload the user pointer (collection flag) for an entity, which shows up using
    has_many :rcprefs, :dependent => :destroy, :as => :entity

    # Scope for the collection of entities that are collected by the user denoted by 'id'
    scope :including_user_pointer, -> (id) { includes(:rcprefs).where rcprefs: { user_id: id } }

    # User_pointers refers to users who have the entity in their collection
    # NB For the case of User models, this provides the users who are following the given user
    has_many :collector_pointers, -> { where(in_collection: true) }, :dependent => :destroy, :as => :entity, :class_name => 'Rcpref'
    # has_many :users, :through => :collector_pointers, :autosave => true, :source=>'user'
    has_many :collectors, :through => :collector_pointers, :autosave => true, :source => 'user'
    # Scope for instances of a class collected by a user, as visible to a possibly different viewer
    scope :collected_by_user, -> (userid, viewerid=userid) {
      joins(:collector_pointers).merge(Rcpref.for_user(userid, viewerid))
    }
    scope :matching_comment, -> (matchstr) {
      joins(:collector_pointers).merge Rcpref.matching_comment(matchstr)
    }

    # Viewer_points refers to all users who have viewed it, whether it's collected or not
    has_many :toucher_pointers, :dependent => :destroy, :as => :entity, :class_name => 'Rcpref'
    has_many :touchers, :through => :toucher_pointers, :autosave => true, :source => 'user'
    scope :viewed_by_user, -> (userid, viewerid=userid) {
      joins(:toucher_pointers).merge(Rcpref.for_user(userid, viewerid, false))
    }                                                                                                                            

    User.collectible self unless self == User # Provides an association to users for each type of collectible (users collecting users are handled specially)
    attr_accessor :page_ref_kind
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # When a rcpref has been updated/created, make sure our associations are current
  def update_associations ref
    self.rcprefs << ref
  end

  def private user_id=User.current_id
    cached_ref(user_id).try(&:private) || false
  end
  alias_method :'collectible_private', :'private'

  def set_private_for newval, user_id=User.current_id
    # Boolean may be coming in as string or integer
    unless newval==true || newval==false
      newval = newval.respond_to?(:to_boolean) ? newval.to_boolean : (newval != nil)
    end
    cached_ref( true, user_id) { |ref| ref.private = newval }
  end
  alias_method :'collectible_private=', :'set_private_for'

  def comment user_id=User.current_id
    cached_ref(user_id).try(&:comment) || ''
  end
  alias_method :collectible_comment, :comment

  def set_comment_for str, user_id=User.current_id
    cached_ref(true, user_id) { |ref| ref.comment = str }
  end
  alias_method :'comment=', :set_comment_for
  alias_method :'collectible_comment=', :set_comment_for

  # Does the entity appear in the user's collection?
  def collected user_id=User.current_id
    cached_ref(false, user_id).try(&:in_collection) || false
  end
  alias_method :'collectible_collected?', :collected

  # Ensure that the collectible is in the collection of [current user]
  def collect user_id=User.current_id
    be_touched user_id, true
  end

  # Remove the collectible from the collection of [current user]
  def uncollect user_id=User.current_id
    be_touched user_id, false
  end

  # Create or update the touch status of this entity with the user
  # collect: true or false sets the in_collection status; nil ignores it
  def be_touched user_id = User.current_id, collect = nil
    unless user_id.class == Fixnum
      user_id, collect = User.current_id, user_id
    end
    cached_ref(true, user_id) do |cr|
      if collect.nil?
        cr.touch if cr.persisted? # Touch will effectively happen when it's saved
      else
        cr.in_collection = collect
      end
    end
  end

  # Present the time-since-touched in a text format
  def touch_date user_id=User.current_id
    cached_ref(false, user_id).try &:updated_at
  end

  # Return the number of times an entity has been marked
  def num_cookmarks
    collector_pointers.count
  end

  # One collectible is being merged into another, so add the new one to the collectors of the old one
  def absorb other
    other.toucher_pointers.each { |other_ref|
      other_ref.in_collection ? other_ref.user.collect(self) : other_ref.user.uncollect(self) # Ensure there's a ref
      if other_ref.comment.present? &&
          (myref = toucher_pointers.where(user: other_ref.user).first) &&
          myref.comment.blank?
        myref.comment = other_ref.comment
        myref.save
      end
    }
    super if defined? super
  end

  protected

  # Maintain a cache of rcprefs by user id
  # assert: build it if it doesn't already exist
  # user_id: the user_id that identifies rcpref for this entity
  def cached_ref assert=false, user_id=User.current_id
    if assert.class == Fixnum
      assert, user_id = false, assert
    end
    if cr = (@cached_refs ||= {})[user_id]
      yield(cr) if block_given?
    else
      unless @cached_refs.has_key?(user_id) # Nil means nil (i.e., no need to lookup the ref)
        cr = @cached_refs[user_id] ||
            # Try to find the ref amongst the loaded refs, if any
            (rcprefs.loaded? && rcprefs.find { |rr| rr.user_id == user_id }) ||
            rcprefs.where(user_id: user_id).first
      end
      # Finally, build a new one as needed
      if cr
        yield(cr) if block_given?
      elsif assert
        cr = rcprefs.new user_id: user_id
        yield(cr) if block_given?
        cr.ensconce
      end
    end
    @cached_refs[user_id] = cr
  end


end

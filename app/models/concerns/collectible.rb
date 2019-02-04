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

=begin
    before_save do
      if @cached_refs
        # We want to save rcprefs that need to be saved because they're not part of an association
        # the sign of which is they're persisted and have an entity_id
        # We save the cached refs that are newly created, under the assumption that
        @cached_refs.values.compact.each { |ref| ref.save unless ref.persisted? && ref.entity_id }
      end
    end
=end

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
    has_many :touchers, :through => :toucher_pointers, :autosave => true
    scope :viewed_by_user, -> (userid, viewerid=userid) {
      joins(:toucher_pointers).merge(Rcpref.for_user(userid, viewerid, false))
    }                                                                                                                            

    User.collectible self unless self == User # Provides an association to users for each type of collectible (users collecting users are handled specially)
    attr_accessor :page_ref_kind
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def update_associations ref, for_sure
    self.rcprefs << ref if for_sure || !rcprefs.where(user_id: ref.user_id, entity: ref.entity).exists?
  end

  def collectible_private
    cached_ref.try(&:private) || false
  end
  alias_method :'private', :'collectible_private'

  # Gatekeeper for the privacy value to interpret strings from checkbox fields
  def collectible_private= newval
    # Boolean may be coming in as string or integer
    unless newval==true || newval==false
      newval = newval.respond_to?(:to_boolean) ? newval.to_boolean : (newval != nil)
    end
    cached_ref( true).private = newval
  end
  alias_method :'private=', :'collectible_private='

  def collectible_comment
    cached_ref.try(&:comment) || ''
  end

  def collectible_comment= str
    cached_ref(true).comment = str
  end

  # Create or update the touch status of this entity with the user
  def be_touched user_id = User.current_id, collect = nil
    unless user_id.class == Fixnum
      user_id, collect = User.current_id, user_id
    end
    cr = cached_ref(true, user_id)
    if collect.nil?
      cr.touch if cr.persisted?
    else
      cr.in_collection = collect
    end
    cr.ensconce # Ready to be added_to/updated in associations for the entity and the user
  end

  # Present the time-since-touched in a text format
  def touch_date user_id=User.current_id
    cached_ref(false, user_id).try &:updated_at
  end

  # Get THIS USER's comment on an entity
  def comment user_id=User.current_id
    cached_ref(false, user_id).try(&:comment) || ''
  end

  # Does the entity appear in the user's collection?
  def collectible_collected? user_id=User.current_id
    cached_ref(false, user_id).try(&:in_collection) || false
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
    unless (@cached_refs ||= {})[user_id]
      unless @cached_refs.has_key?(user_id)
        @cached_refs[user_id] ||=
            # Try to find the ref amongst the loaded refs, if any
            (rcprefs.loaded? && rcprefs.find { |rr| rr.user_id == user_id }) ||
            rcprefs.find_by(user_id: user_id)
      end
      # Finally, build a new one as needed
      @cached_refs[user_id] ||= rcprefs.new user_id: user_id if assert
    end
    @cached_refs[user_id]
  end


end

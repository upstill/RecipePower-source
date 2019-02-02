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

    before_save do
      if @cached_refs
        @cached_refs.values.compact.each { |rr| rr.save if rr.changed? }
      end
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

  def be_collected newval=true
    newval = (newval.to_boolean || false) unless newval==true || newval==false
    cached_ref(true).in_collection = newval
  end
  alias_method :'collect', :'be_collected'

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
      other_ref.user.touch self, other_ref.in_collection # Ensure there's a ref
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

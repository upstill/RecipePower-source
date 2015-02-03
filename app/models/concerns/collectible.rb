module Collectible
  extend ActiveSupport::Concern
  include Taggable
  include Voteable
  include Picable

  included do
    before_save do
      boolean_private = @collectible_private.to_i == 1
      if @collectible_user_id # It must have been set
        @collectible_user_id = @collectible_user_id.to_i # Better to have it as an integer
        if ref = cached_ref
          ref.comment = @collectible_comment
          ref.private = boolean_private
          ref.in_collection = @collectible_in_collection
          ref.save
        else
          user_pointers.create user_id: @collectible_user_id, comment: @collectible_comment, private: boolean_private
        end
      end
    end

    has_many :user_pointers, :dependent => :destroy, :as => :entity, :class_name => "Rcpref"
    has_many :users, :through => :user_pointers, :autosave => true
    User.collectible self unless self == User # Provides an association to users for each type of collectible (users collecting users are handled specially)
    # attr_accessor :collectible_userid, :collectible_comment, :collectible_private # Virtual attributes for editing
    # attr_accessible :collectible_userid, :collectible_comment, :collectible_private # Virtual attributes for editing
    attr_accessor :collectible_user_id, :collectible_comment, :collectible_private # For editng purposes: the cached_ref for the current user (collection required)
    attr_accessible :collectible_user_id, :collectible_comment, :collectible_private
  end

  # Prepare for editing the model by setting the collectible attributes
  def uid= uid
    @collectible_user_id = uid
    if !@current_ref || (@current_ref.user_id != uid) # Bust the cache
      @current_ref = nil
      # These are the default values for the associated rcpref. If accessed they will be replaced by the values from the ref
      @collectible_comment = ""
      @collectible_private = 0
      @collectible_in_collection = false
    end
    # Work back up the hierarchy
    super if defined? super
  end

  def private= priv
    cached_ref
    @collectible_private = priv ? 1 : 0
  end

  def collect going_in=true
    cached_ref
    @collectible_in_collection = (going_in ? true : false)
  end

  # Present the time-since-touched in a text format
  def touch_date uid=nil
    if ref = ref_if_any(uid)
      ref.updated_at
    end
  end

  # The comment for an entity comes from its user_pointers for a given user_id
  # Get THIS USER's comment on an entity
  def comment uid=nil
    ref = ref_if_any uid
    return @collectible_comment if @current_ref && ref == @current_ref
    (ref && ref.comment) || ""
  end

  def private uid=nil
    ref = ref_if_any uid
    return (@collectible_private == 1) if @current_ref && ref == @current_ref
    (ref && ref.private) ? true : false
  end

  # Does the entity appear in the user's collection?
  def collected? uid=nil
    ref = ref_if_any uid
    return @collectible_in_collection if @current_ref && ref == @current_ref
    ref && ref.in_collection
  end

  # Return the number of times a recipe's been marked
  def num_cookmarks
    user_pointers.where(in_collection: true).count
  end

  # One collectible is being merged into another, so add the new one to the collectors of the old one
  def absorb other
    other.user_pointers.each { |ref| ref.user.touch self, ref.in_collection }
    super if defined? super
  end

  protected

  # Check for the existence of a reference and return it, but don't create one
  def ref_if_any uid=nil
    uid ||= @collectible_user_id
    return @current_ref if @current_ref && (@current_ref.user_id == uid) # May already be cached as the current ref
    # So it's not cached
    (uid==@collectible_user_id) ? # If it's the current id, we capture the ref
        cached_ref(false) :
        user_pointers.where(user_id: uid, entity: self).first
  end

  # Return the reference for the given user and this entity, creating a new one as necessary
  # If 'force' is set, and there is no reference to the entity for the user, create one
  def cached_ref force=true
    unless @current_ref && (@current_ref.user_id == @collectible_user_id)
      # A user is specified, but the currently-cached ref doesn't match
      if @current_ref = (force ?
        user_pointers.find_or_initialize_by(user_id: @collectible_user_id, entity_type: self.class.to_s, entity_id: self.id) :
        user_pointers.where(user_id: @collectible_user_id, entity: self).first)
        @collectible_comment = @current_ref.comment || ""
        @collectible_private = @current_ref.private? ? 1 : 0
        @collectible_in_collection = @current_ref.in_collection
      end
    end
    @current_ref
  end

end

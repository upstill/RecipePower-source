module Collectible
  extend ActiveSupport::Concern
  include Taggable
  include Voteable
  include Picable

  included do
    before_save do
      if @collectible_user_id # It must have been set
        @collectible_user_id = @collectible_user_id.to_i # Better to have it as an integer
        if (@current_ref && (@current_ref.user_id == @collectible_user_id)) ||
            (@current_ref = toucher_pointers.find_by(user_id: @collectible_user_id))
          @current_ref.comment = @collectible_comment
          @current_ref.private = @collectible_private
          @current_ref.in_collection = @collectible_in_collection
          @current_ref.save
        else
          @current_ref = viewer_pointers.create user_id: @collectible_user_id, comment: @collectible_comment, private: boolean_private
        end
      end
    end

    # User_pointers refers to users who have the entity in their collection
    has_many :user_pointers, -> { where(in_collection: true) }, :dependent => :destroy, :as => :entity, :class_name => "Rcpref"
    has_many :users, :through => :user_pointers, :autosave => true

    # Viewer_points refers to all users who have viewed it, whether it's collected or not
    has_many :toucher_pointers, :dependent => :destroy, :as => :entity, :class_name => "Rcpref"
    has_many :touchers, :through => :toucher_pointers, :autosave => true

    User.collectible self unless self == User # Provides an association to users for each type of collectible (users collecting users are handled specially)
    # attr_accessor :collectible_userid, :collectible_comment, :collectible_private # Virtual attributes for editing
    # attr_accessible :collectible_userid, :collectible_comment, :collectible_private # Virtual attributes for editing
    attr_accessor :collectible_user_id, :collectible_comment # For editng purposes: the cached_ref for the current user (collection required)
    attr_reader :collectible_private
    attr_accessible :collectible_user_id, :collectible_comment, :collectible_private
  end

  # Prepare for editing the model by setting the collectible attributes
  def uid= uid
    @collectible_user_id = uid
    cached_ref  # Bust the cache but update the collectible attributes to reflect the ref assoc'd with this id
    # Work back up the hierarchy
    super if defined? super
  end

  def private= priv
    cached_ref
    self.collectible_private = priv
  end

  # Gatekeeper for the privacy value to interpret strings from checkbox fields
  def collectible_private= newval
    # Boolean may be coming in as string or integer
    case newval
      when Fixnum
        @collectible_private = (newval == 1)
      when String
        @collectible_private = (newval == "1")
      when nil
        @collectible_private = false
      else
        @collectible_private = newval
    end
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
    return collectible_private if @current_ref && ref == @current_ref
    ref.private if ref
  end

  # Does the entity appear in the user's collection?
  def collected? uid=nil
    ref = ref_if_any uid
    return @collectible_in_collection if @current_ref && ref == @current_ref
    ref.in_collection if ref
  end

  # Return the number of times a recipe's been marked
  def num_cookmarks
    user_pointers.count
  end

  # One collectible is being merged into another, so add the new one to the collectors of the old one
  def absorb other
    other.toucher_pointers.each { |ref| ref.user.touch self, ref.in_collection }
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
        toucher_pointers.where(user_id: uid, entity: self).first
  end

  # Return the reference for the given user and this entity, creating a new one as necessary
  # If 'force' is set, and there is no reference to the entity for the user, create one
  def cached_ref force=true
    unless @current_ref && (@current_ref.user_id == @collectible_user_id)
      # A user is specified, but the currently-cached ref doesn't match
      if @current_ref = (force ?
          toucher_pointers.find_or_initialize_by(user_id: @collectible_user_id) :
          toucher_pointers.where(user_id: @collectible_user_id).first)
        @collectible_comment = @current_ref.comment || ""
        @collectible_private = @current_ref.private
        @collectible_in_collection = @current_ref.in_collection
      end
    end
    @current_ref
  end

end

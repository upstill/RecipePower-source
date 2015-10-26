module Collectible
  extend ActiveSupport::Concern
  include Taggable
  include Voteable
  include Picable

  included do
    before_save do
      @cached_ref.save if cached_ref_valid? # It must have been set
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
    attr_accessible :collectible_user_id, :collectible_comment, :collectible_private
  end

  # Prepare for editing the model by setting the collectible attributes
  def uid= uid
    @collectible_user_id = uid.to_i
    # cached_ref  # Bust the cache but update the collectible attributes to reflect the ref assoc'd with this id
    # Work back up the hierarchy
    super if defined? super
  end

  def collectible_user_id
    @collectible_user_id
  end

  def collectible_user_id= id
    @collectible_user_id=id.to_i
  end

  def collectible_private
    cached_ref(false) ? @cached_ref.private : false
  end

  # Gatekeeper for the privacy value to interpret strings from checkbox fields
  def collectible_private= newval
    # Boolean may be coming in as string or integer
    cached_ref(true).private = newval.respond_to?(:to_boolean) ? newval.to_boolean : (newval != nil)
  end

  alias_method :'private=', :'collectible_private='

  def collectible_comment
    cached_ref(false) ? @cached_ref.comment : ''
  end

  def collectible_comment= str
    cached_ref.comment = str
  end

  def be_collected newval=true
    cached_ref.in_collection = newval.respond_to?(:to_boolean) ? newval.to_boolean : (newval != nil)
  end

  # Present the time-since-touched in a text format
  def touch_date uid=nil
    if ref = ref_if_any(uid)
      ref.updated_at
    end
  end

  # Get THIS USER's comment on an entity
  def comment uid=nil
    (ref = ref_if_any uid) ? ref.comment : ""
  end

  def private uid=nil
    (ref = ref_if_any uid) && ref.private
  end

  # Does the entity appear in the user's collection?
  def collectible_collected? uid=nil
    (ref = ref_if_any uid) && ref.in_collection
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
    (uid==@collectible_user_id) ? # If it's the current id, we capture the ref
        cached_ref(false) :
        toucher_pointers.where(user_id: uid).first
  end

  def cached_ref_valid?
    @collectible_user_id && @cached_ref && (@cached_ref.user_id == @collectible_user_id)
  end

  # Return the reference for the given user and this entity, creating a new one as necessary
  # If 'force' is set, and there is no reference to the entity for the user, create one
  def cached_ref force=true
    unless cached_ref_valid?
      # A user is specified, but the currently-cached ref doesn't match
      @cached_ref = (force ?
          toucher_pointers.find_or_initialize_by(user_id: @collectible_user_id) :
          toucher_pointers.where(user_id: @collectible_user_id).first)
    end
    @cached_ref
  end

end

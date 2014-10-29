module Collectible
  extend ActiveSupport::Concern

  included do
    has_many :rcprefs, :dependent => :destroy, :as => :entity
    has_many :users, :through => :rcprefs, :autosave => true
    # after_save { (ref = rcpref nil, false) && ref.save } # Ensure that the ref is saved
    User.collectible self unless self == User # So that users can collect users
    # attr_accessor :collectible_userid, :collectible_comment, :collectible_private # Virtual attributes for editing
    # attr_accessible :collectible_userid, :collectible_comment, :collectible_private # Virtual attributes for editing
    attr_accessor :collectible_user_id, :collectible_comment, :collectible_private # For editng purposes: the rcpref for the current user (collection required)
    attr_accessible :collectible_user_id, :collectible_comment, :collectible_private
  end
  
  def add_to_collection uid
    self.touch true, uid # Touch the entity and add it to the user's collection
  end

  def remove_from_collection uid
    if (ref = rcpref(uid, false)) and ref.in_collection
      ref.in_collection = false
      ref.save
    end
  end

  # Does the entity appear in the user's collection?
  def collected_by? uid
    (ref = rcpref(uid, false)) && ref.in_collection
  end

  # Present the time-since-touched in a text format
  def touch_date uid
    if (ref = rcpref uid, false)
      ref.updated_at
    end
  end

  # The comment for an entity comes from its rcprefs for a given user_id
  # Get THIS USER's comment on an entity
  def comment uid=nil
    uid ?
      (((ref = rcpref uid, false) && ref.comment) || "") :
      @comment
  end

  def private uid=nil
    return @private unless uid
    if (ref = rcpref(uid, false))
      ref.private
    end
  end

  # Return the number of times a recipe's been marked
  def num_cookmarks
    rcprefs.where(in_collection: true).count
  end

  # Prepare for editing the model by setting the collectible attributes
  def define_collectible_attributes uid
    self.collectible_user_id = uid
    if ref = rcpref(uid, false) # Pre-existing collection object
      self.collectible_comment = ref.comment
      self.collectible_private = ref.private
    else
      self.collectible_comment = ""
      self.collectible_private = false
    end
  end

  # After editing the model, save the collectible attributes in an Rcpref
  def accept_collectible_attributes
    if ref = rcpref(collectible_user_id, false)
      ref.comment = collectible_comment
      ref.private = collectible_private
      ref.save
    else
      rcprefs.create user_id: collectible_user_id, comment: collectible_comment, private: collectible_private
    end
  end

  protected

  # Return the reference for the given user and this entity, creating a new one as necessary
  # If 'force' is set, and there is no reference to the entity for the user, create one
  def rcpref uid, force=true
    unless @current_ref && (@current_ref.user_id == uid)
      # A user is specified, but the currently-cached ref doesn't match
      @current_ref = force ?
        rcprefs.find_or_initialize_by(user_id: uid, entity_type: self.class.to_s, entity_id: self.id) :
        rcprefs.where(user_id: uid, entity: self).first
    end
    @current_ref
  end

  public

end

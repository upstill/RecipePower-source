module Collectible
  extend ActiveSupport::Concern

  included do
    has_many :rcprefs, :dependent => :destroy, :as => :entity
    has_many :users, :through => :rcprefs, :autosave => true
    after_save { (ref = rcpref nil, false) && ref.save } # Ensure that the ref is saved
    User.collectible self unless self == User # So that users can collect users
  end
  
  attr_accessor :current_user

  def add_to_collection uid=nil
    self.touch true, uid # Touch the entity and add it to the user's collection
  end

  def remove_from_collection uid=nil
    if (ref = rcpref(uid, false)) and ref.in_collection
      ref.in_collection = false
      ref.save
    end
  end

  # Does the entity appear in the user's collection?
  def collected_by? uid=nil
    (ref = rcpref(uid, false)) && ref.in_collection
  end

  # Set the mod time of the entity to now (so it sorts properly in Recent lists)
  # If a uid is provided, touch the associated rcpref instead
  def touch add_to_collection = true, user = nil
    # Fetch the reference for this user, creating it if necessary
    return unless (ref = rcpref(user)) # Make if necessary--but not without a user

    # Just touching doesn't take the entity out of the collection
    if do_save = (add_to_collection && !ref.in_collection)
      ref.in_collection = true
      do_stamp = ref.created_at && ((Time.now - ref.created_at) > 5) # It's been saved before => update created_at time
    end
    do_save = true if ref.created_at.nil?
    if do_stamp
      ref.created_at = ref.updated_at = Time.now
      Rcpref.record_timestamps=false
      ref.save
      Rcpref.record_timestamps=true
    elsif do_save # Save, whether previously saved or not
      ref.save
    else
      ref.touch
    end
    "Created: #{ref.created_at}.........Updated: #{ref.updated_at}"
  end

  # Present the time-since-touched in a text format
  def touch_date uid=nil
    if (ref = rcpref uid, false)
      ref.updated_at
    end
  end

  # Present the time since collection in a text format
  def collection_date uid=nil
    if (ref = rcpref uid, false) && ref.in_collection
      ref.created_at
    end
  end

  # The comment for an entity comes from its rcprefs for a given user_id
  # Get THIS USER's comment on an entity
  def comment uid=nil
    ((ref = rcpref uid, false) && ref.comment) || ""
  end

  # Record THIS USER's comment in the reciperefs join table
  def comment=(str)
    if ref = rcpref
      ref.comment = str
    end
  end

  def private uid=nil
    if (ref = rcpref(uid, false))
      ref.private
    end
  end

  # Casual setting of privacy for the entity's current user.
  def private=(val)
    if ref = rcpref
      ref.private = (val == false) || (val != "0")
    end
  end

  # Set the updated_at field for the rcpref for this user and this recipe
  def uptouch(uid, time)
    ref = rcpref uid
    if time > ref.updated_at
      Rcpref.record_timestamps=false
      ref.updated_at = time
      ref.save
      Rcpref.record_timestamps=true
    else
      false
    end
  end

  # Return the number of times a recipe's been marked
  def num_cookmarks
    rcprefs.where(in_collection: true).count
  end

  protected

  # Return the reference for the given user and this entity, creating a new one as necessary
  # If 'force' is set, and there is no reference to the entity for the user, create one
  def rcpref uid=nil, force=true
    return (@current_ref = nil) unless uid ||= @current_user  # No ref without a user
    unless @current_ref && (@current_ref.user_id == uid)
      # A user is specified, but the currently-cached ref doesn't match
      @current_ref = rcprefs.where(user_id: uid).first || (force && rcprefs.create(user_id: uid))
    end
    @current_user = uid
    @current_ref
  end

  public

end
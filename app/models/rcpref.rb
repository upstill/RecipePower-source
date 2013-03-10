class Rcpref < ActiveRecord::Base
    belongs_to :recipe
    belongs_to :user
    # before_save :ensure_unique
    attr_accessible :comment, :recipe_id, :user_id, :in_collection, :updated_at, :created_at

    StatusRotationMask = 0x1
    StatusFavoritesMask = 0x2
    StatusInterestingMask = 0x4
    StatusMiscMask = 0x8
    StatusAny = StatusRotationMask | StatusFavoritesMask | StatusInterestingMask | StatusMiscMask 
    StatusRecentMask = 0x10

    # Get the user-assigned status for a recipe as a hash of booleans
    # :status_rotation
    # :status_favorites
    # :status_interesting
    # :status_misc
    def status_flags
	status_bits_to_flags(self.status)
    end

    def status_flags=(flags)
	self.status = status_flags_to_bits flags
    end
    
    # Present the time-since-touched in a text format
    def self.touch_date(rid, uid)
        if rr = Rcpref.where(recipe_id: rid, user_id: uid).first
          rr.updated_at
        end
    end
  
    # When saving a "new" use, make sure it's unique
    def ensure_unique
        puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.recipe_id.to_s}"
    end

  # get an array of recipe ids from a user, subject to permissions and status, with appropriate ordering
  # owner_id can be:
  #   nil => all recipes in the world
  #   single id => the recipes for a particular owner
  #   [array of ids] => recipes from them all
  def Rcpref.recipe_ids(owner_id, requestor_id, *params)
	# requestor_id is the user_id of the user requesting the list; resulting set will be filtered according
	#    to the relationship between the two users
	# :comment is text to match against the comment field
	# :title is text to match against the recipe's title 
	# NB: If both are given, recipes are returned which match in either
	# :status is the set of status flags to match
	# :sorted gives criterion for sorting (currently only sort by updated_at field)
  args = params.first || {}
  commentstr = args[:comment]
  titlestr = args[:title]
  sortfield = args[:sorted]
	statuses = args[:status] || StatusAny

	sort_by_touched = args[:status] & StatusRecentMask 
	if owner_id.kind_of? Fixnum
	    owner_is_super = (owner_id == User.super_id)
	    owner_is_requestor = (owner_id == requestor_id)
	end
	# We reduce the relation based on owner_id unless the requestor is nil or super
	if owner_is_super
	  # super sees all
	  refs = Rcpref.scoped
    else
	  refs = owner_id.nil? ? Rcpref.scoped : Rcpref.where(user_id: owner_id) # NB: owner_id can be an array of ids
	
	  refs = refs.where("NOT private") unless owner_is_requestor 

	  # Unless we're going for restricted status, just get 'em all
	  refs = refs.where("status <= ?", statuses) if statuses < StatusMiscMask
	end

    refs = refs.order(sortfield) if sortfield
    refs = refs.order("updated_at").reverse_order() if sort_by_touched
    
    # We apply the titlestr, if any
    if titlestr
 	  regexp = /#{titlestr}/i
      titleset = refs.keep_if{ |rr| rr.recipe.title =~ regexp }
    end
    
    if commentstr
	  # If there is a :comment parameter, use that in the query
	  commentset = refs.where("comment LIKE ?", "%"+commentstr+"%")
    end
    
    # We prefer recipes that match in both title and comment, 
    # otherwise, first title matches, then comment matches
    if commentset && titleset
        refs = (commentset & titleset) | titleset | commentset
    else
        refs = titleset || commentset || refs
    end
    
    # Just return the list of recipe ids
	refs.map &:recipe_id
end

    def status_bits_to_flags(bits)
	{:status_rotation=>(bits & StatusRotationMask),
	 :status_favorites=>(bits & StatusFavoritesMask),
	 :status_interesting=>(bits & StatusInterestingMask),
	 :status_misc=>(bits & StatusMiscMask)}
    end

    def status_flags_to_bits(flags)
        (flags[:status_rotation] ? StatusRotationMask : 0) |
        (flags[:status_favorites] ? StatusFavoritesMask : 0) |
        (flags[:status_interesting] ? StatusInterestingMask : 0) |
        (flags[:status_misc] ? StatusMiscMask : 0)
    end

=begin

PermissionPrivateMask = 0x1
PermissionFriendsMask = 0x2
PermissionCirclesMask = 0x4
PermissionPublicMask = 0x8
PermissionAll = PermissionPrivateMask | PermissionFriendsMask | PermissionCirclesMask | PermissionPublicMask 

    # Get the user-assigned permissions for a recipe as a hash of booleans
    def privacy_flags=(flags)
      self.privacy = privacy_flags_to_bits flags
    end

    # Get the user-assigned permissions for a recipe as a hash of booleans
    #	:permission_public
    #	:permission_friends
    #	:permission_circles
    #	:permission_private
    def privacy_flags
    privacy_bits_to_flags(self.privacy)
    end
    
    def privacy_bits_to_flags(bits)
	{:permission_private=>(bits & PermissionPrivateMask),
	 :permission_friends=>(bits & PermissionFriendsMask),
	 :permission_circles=>(bits & PermissionCirclesMask),
	 :permission_public=>(bits & PermissionPublicMask)}
    end

    def privacy_flags_to_bits(flags)
	(flags[:permission_private] ? PermissionPrivateMask : 0) |
	(flags[:permission_friends] ? PermissionFriendsMask : 0) |
	(flags[:permission_circles] ? PermissionCirclesMask : 0) |
	(flags[:permission_public] ? PermissionPublicMask : 0)
    end
=end
end

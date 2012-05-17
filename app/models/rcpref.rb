class Rcpref < ActiveRecord::Base
    belongs_to :recipe
    belongs_to :user
    # before_save :ensure_unique
    attr_accessible :comment, :recipe_id, :user_id

    PermissionPrivateMask = 0x1
    PermissionFriendsMask = 0x2
    PermissionCirclesMask = 0x4
    PermissionPublicMask = 0x8
    PermissionAll = PermissionPrivateMask | PermissionFriendsMask | PermissionCirclesMask | PermissionPublicMask 

    StatusRotationMask = 0x1
    StatusFavoritesMask = 0x2
    StatusInterestingMask = 0x4
    StatusMiscMask = 0x8
    StatusAny = StatusRotationMask | StatusFavoritesMask | StatusInterestingMask | StatusMiscMask 
    StatusRecentMask = 0x10

    # Get the user-assigned permissions for a recipe as a hash of booleans
    #	:permission_public
    #	:permission_friends
    #	:permission_circles
    #	:permission_private
    def privacy_flags
	privacy_bits_to_flags(self.privacy)
    end

    # Get the user-assigned permissions for a recipe as a hash of booleans
    def privacy_flags=(flags)
	self.privacy = privacy_flags_to_bits flags
    end

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

    # When saving a "new" use, make sure it's unique
    def ensure_unique
puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.recipe_id.to_s}"
    end

    # get an array of recipe ids from a user, subject to permissions and status
    def Rcpref.recipe_ids(owner_id, requestor_id, *params)
	# owner_id indexes the owner: 'guest' and 'super' are special "owners"
	#  of all recipes (subject to permission)
	# requestor_id is the user_id of the user requesting the list
	# :comment is text to match against the comment field
	# :title is text to match against the recipe's title 
	# NB: If both are given, recipes are returned which match in either
	# :status is the set of status flags to match

    commentstr = params.first[:comment]
    titlestr = params.first[:title]
	# We accumulate a list of constraints and their parameters for passing to self.where
	constraints = []
	parameters = []
	
	case requestor_id 
	   when User.guest_id
	      # Guest gets only public recipes
	      constraints << "privacy <= ?"
	      parameters << PermissionPublicMask
	   when User.super_id
	      # Super-user sees all
	      permissions = PermissionAll
	   when owner_id
	      # Owner of list sees all in the list
              permissions = PermissionAll
	   else
	      # XXX We SHOULD be deriving permission bits from other considerations:
	      # * If the two users share membership in some group, then set Groups bit
	      # * If the two users are friends, then set Friends bit
	      permissions = PermissionAll
	end

	# Derive the status part of the query from the :status parameter
	statuses = params.first[:status] || StatusAny
	# Unless we're going for restricted status, just get 'em all
	if statuses < StatusMiscMask
	   constraints << "status <= ?"
	   parameters << statuses
	end

	# Collect constraint for user id (if not guest or super)
	# Both guests and super get everything, regardless of owner
	# (subject to permissions)
	if owner_id != User.guest_id && owner_id != User.super_id
	   constraints << "user_id = ?"
	   parameters << owner_id
	end

	# If there is a :comment parameter, use that in the query
	# THIS MUST BE THE TOP OF THE STACK
	if commentstr
	   constraints << "comment LIKE ?"
	   parameters << "%"+commentstr+"%" # Match within
	end

    if constraints.empty? 
        if owner_id == User.super_id
            # We return all recipe ids, possibly filtering for title
            if titlestr
                rcpids = Recipe.where( 'title LIKE ?', "%#{titlestr}%").map { |r| r.id }
            else
                rcpids = Recipe.select(:id).map { |r| r.id }
            end
            return rcpids
        else
        	allrefs = self.find :all 
        end
    else
    	allrefs = self.where(constraints.join(' AND '), *parameters)
    end

	# Handle the case(s) where there is a title constraint
	#  If there is a comment constraint, find without that constraint, then filter
	#  otherwise, filter the prior list
	if titlestr
	   regexp = /#{titlestr}/i
	   if commentstr 
	       constraints.pop
	       parameters.pop
	       more = constraints.empty? ?
	       		  self.find(:all) :
			  self.where(constraints.join(' AND '), *parameters)
	       allrefs += more.keep_if{ |rr| 
	       		Recipe.find(rr.recipe_id).title =~ regexp }
	       allrefs.uniq!
	   else
	       allrefs.keep_if{ |rr| 
	       		Recipe.find(rr.recipe_id).title =~ regexp }
	   end
	end

	if owner_id != User.super_id
    	# XXX Should be moved to a migration
    	allrefs.each do |rr| 
    	   unless rr.privacy && rr.status && rr.comment
    	      rr.privacy = PermissionAll unless rr.privacy
    	      rr.status = StatusMiscMask unless rr.status
    	      rr.comment = "" unless rr.comment
    	      rr.save
    	   end
    	end
    	# Reduce the results to a set of recipe keys
    	if params.first[:status] & StatusRecentMask 
    	    # sort by creation date
    	    allrefs.sort! { |a, b| b.updated_at <=> a.updated_at }
    	end
	end
	allrefs.map { |rr| rr.recipe_id }.uniq
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

end

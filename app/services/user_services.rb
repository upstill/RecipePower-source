class UserServices
  
  attr_accessor :user
  
  delegate :id, :typename, :name, :normalized_name, :primary_meaning, :isGlobal, 
    :users, :user_ids, :owners, :owner_ids, :reference_count, :referents, :can_absorb, :to => :tag
  
  def initialize(user)
    self.user = user
  end

  def analyze_invitees(against_user)
    result = {
      redundancies:  [], # Current friends (member's share notice sent)
      pending:  [], # Invited but not yet confirmed
      new_friends:  [], # Newly-added friends (member's share notice sent)
      to_invite:  []
    }
    @user.invitee_tokens.each do |invitee|
      u = 
      case invitee
      when Fixnum # ID of existing friend
        User.find invitee
      when String # email address which may or may not be external
        User.where(email: invitee.downcase).first
      end
      if u
        # Existing user, whether signed up or not, friend or not
        if against_user.followee_ids.include? u.id # Existing friend: redundant
          result[:redundancies] << u
        elsif u.last_sign_in_at # The user has ever signed in (not a pending invitation)
          result[:new_friends] << u
        else # User never signed in -> invitation is pending
          result[:pending] << u
        end
      else
        result[:to_invite] << invitee
      end
    end
    result
  end

end
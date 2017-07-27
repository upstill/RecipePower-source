require 'reference.rb'
class UserServices
  
  attr_accessor :user
  
  delegate :id, :username, :first_name, :last_name, :fullname, :about, :login, :private, :skip_invitation, :add_collection, :delete_collection, :add_followee,
           :email, :password, :password_confirmation, :shared_class, :shared_name, :shared_id, :shared, :'shared=', :invitee_tokens, :image,
           :remember_me, :role_id, :sign_in_count, :invitation_message, :followee_tokens, :subscription_tokens, :invitation_issuer, :to => :user
  
  def initialize(user)
    self.user = user
  end

  def self.convert_all_to_references n=-1
    User.where("image <> ''")[0..n].each do |u|
      unless u.image.blank?
        u.image = u.image  # Creates the reference
      end
      u.thumbnail && u.thumbnail.perform
      u.save
    end
    'Users Converted'
  end

  def analyze_invitees(sender)
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
        if sender.followee_ids.include? u.id # Existing friend: redundant
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
    
    # Define a singleton method on the hash for reporting out the results
    def result.report(which, selector = nil) 
      unless (items = self[which]).empty?
        count = items.size
        items = liststrs(items.map(&selector)) if selector
        yield(items, count)
      end
    end
    
    result
  end

  # Called on signup to initialize the user
  def sign_up
    # Give the user a starting set of collections and friends
    List.assert 'Now Cooking', user
    List.assert 'To Try', user
    List.assert 'Keepers', user
    add_followee User.find(1)
    add_followee User.find(3)
  end
end

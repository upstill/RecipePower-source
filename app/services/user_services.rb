require 'reference.rb'
class UserServices
  
  attr_accessor :user
  
  delegate :id, :username, :first_name, :last_name, :fullname, :about, :login, :private, :skip_invitation, :add_collection, :delete_collection,
           :email, :password, :password_confirmation, :shared_recipe, :invitee_tokens, :channel_tokens, :image,
           :remember_me, :role_id, :sign_in_count, :invitation_message, :followee_tokens, :subscription_tokens, :invitation_issuer, :to => :user
  
  def initialize(user)
    self.user = user
  end

  def self.convert_all_to_references n=-1
    User.where("image <> ''")[0..n].each do |u|
      u.thumbnail = ImageReference.find_or_create u.image
      u.save
    end
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

  def self.tagify_status
    User.all.each { |user| self.new(user).tagify_status }
  end

  # Convert the status markers for recipes into a collection
  def tagify_status
    statusval = 1
    tags = []
    ['Now Cooking', 'Keepers', 'To Try' ].each do |tagname|
      # Assert user's inclusion in tag
      # For each recipe of that status, apply appropriate tag
      self.add_collection (tags[statusval] = Tag.assert_tag(tagname, userid: id)), statusval
      statusval *= 2
    end
    Rcpref.where(status: [1,2,4], user_id: id).each do |rr|
      rr.recipe.tag_with tags[rr.status], id
    end
    @user.refresh_browser
  end
end

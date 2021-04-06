require 'image_reference.rb'
class UserServices
  
  attr_accessor :user
  
  delegate :id, :username, :first_name, :last_name, :fullname, :about, :login, :private, :skip_invitation, :collect,
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

  # Read a file of Mailgun errors and unsubscribe users whose email addresses failed
  def self.unsubscribe_on_errors
    emails = File.open("failures.txt").collect { |line|
      # The email address follows the '→' character
      if m = line.match(/→\s+(\S*\b)/)
        m[1]
      end
    }.compact
    User.where(email: emails, subscribed: true).map { |user| user.update_attribute :subscribed, false }
  end

=begin
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
      when Integer # ID of existing friend
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
=end

  # Called on signup to initialize the user
  def sign_up
    # Give the user a starting set of collections and friends
    List.assert 'Now Cooking', user
    List.assert 'To Try', user
    List.assert 'Keepers', user
    collect User.find(1)
    collect User.find(3)
  end

  def self.glean_names
    changed = User.all.to_a.keep_if { |u|
      keep = false
      if u.first_name.blank?
        if u.fullname.present?
          logger.debug "#{u.id}(#{u.email}=#{u.username}): #{u.first_name} | #{u.last_name} | #{u.fullname}"
          keep = UserServices.new(u).glean_names
          logger.debug " => #{u.first_name} | #{u.last_name}"
        else
          logger.debug "Dud: #{u.id}(#{u.email}=#{u.username}): #{u.first_name} | #{u.last_name} | #{u.fullname}"
        end
      end
      keep
    }
    changed.each { |u|
      logger.debug "'#{u.fullname}' => #{u.first_name} | #{u.last_name} (#{u.id}/#{u.email}/#{u.username})"
    }
    nil
  end

  def self.fix_user id, name
    names = name.split
    first_name = names.first
    last_name = (names.last if names.count > 1)
    u = User.find_by id: id
    u.first_name = first_name
    if last_name.present?
      u.last_name = last_name
      u.fullname = "#{first_name} #{last_name}"
    end
    u.save
    logger.debug "#{u.id}(#{u.email}=#{u.username}): #{u.first_name} | #{u.last_name} | #{u.fullname}"
  end

  # Infer default first and last names from the full name, and vice versa
  def glean_names
    if fullname.present?
      names = fullname.split
      # if names.count > 1
        user.first_name = names.first unless first_name.present?
        user.last_name = names.last if names.count > 1 && last_name.blank?
        user.save
      # end
    elsif first_name.present? && last_name.present?
      user.fullname = "#{first_name} #{last_name}"
      user.save
    end
  end

  def self.fix_names
    # Interactively sort out names
    User.where(first_name: nil).each { |u|
      logger.debug "#{u.id}(#{u.email}): #{u.first_name} | #{u.last_name} | #{u.fullname}"
      name = gets
      return unless name && name.length > 0
      name.chomp!
      UserServices.fix_user u.id, name if name.length > 0
    }
  end

end

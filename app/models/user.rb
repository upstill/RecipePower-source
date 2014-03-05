require "type_map.rb"
require "rcp_browser.rb"
class User < ActiveRecord::Base
  include Taggable
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :timeoutable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable #, :validatable,
         :lockable # , :omniauthable
  after_invitation_accepted :initialize_friends
  before_save :serialize_browser

  # Setup accessible (or protected) attributes for your model
  attr_accessible :id, :username, :first_name, :last_name, :fullname, :about, :login, :private, :skip_invitation,
                :email, :password, :password_confirmation, :shared_recipe, :invitee_tokens, :channel_tokens, :image,
                :remember_me, :role_id, :sign_in_count, :invitation_message, :followee_tokens, :subscription_tokens, :invitation_issuer
  attr_writer :browser
  attr_accessor :shared_recipe, :invitee_tokens, :channel_tokens, :raw_invitation_token
  
  has_many :rcprefs, :dependent => :destroy
  has_many :recipes, :through=>:rcprefs, :autosave=>true
  
  has_many :notifications_sent, :foreign_key => :source_id, :class_name => "Notification", :dependent => :destroy
  has_many :notifications_received, :foreign_key => :target_id, :class_name => "Notification", :dependent => :destroy

  has_many :follower_relations, :foreign_key=>"followee_id", :dependent=>:destroy, :class_name=>"UserRelation"
  has_many :followers, -> { uniq }, :through => :follower_relations, :source => :follower

  has_many :followee_relations, :foreign_key => "follower_id", :dependent=>:destroy, :class_name => "UserRelation"
  has_many :followees, -> { uniq }, :through => :followee_relations, :source => :followee
  
  # Channels are just another kind of user. This field (channel_referent_id, externally) denotes such.
  belongs_to :channel, :class_name => "Referent", :dependent => :destroy, :foreign_key => "channel_referent_id"
  
  has_and_belongs_to_many :feeds
  
  # login is a virtual attribute placeholding for [username or email]
  attr_accessor :login
  
  def browser params=nil
    return @browser if @browser && !params
    # Try to get browser from serialized storage in the user record
    # If something goes awry, we'll just create a new one.
    begin
      @browser = ContentBrowser.load browser_serialized
    rescue Exception => e
      @browser = nil
    end
    @browser ||= ContentBrowser.new id
    # Take heed of any query parameters that apply to the browser
    @browser.apply_params(params) if params
    @browser
  end
  
  # Bust the browser cache due to selections changing, optionally selecting an object
  def refresh_browser(obj = nil)
    browser_serialized = nil
    @browser = ContentBrowser.new(id)
    @browser.select_by_content(obj) if obj
    save
  end
  
  def serialize_browser
    self.browser_serialized = @browser.dump if @browser
  end
  
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  # Add the feed to the browser's ContentBrowser and select it
  def add_feed feed
    if feeds.exists? id: feed.id
      browser.select_by_content feed
    else
      self.feeds = feeds.unshift(feed)
      refresh_browser feed
    end
  end

  def delete_feed feed
    browser.select_by_content feed
    browser.delete_selected
    feeds.delete feed
    save
  end

  def add_followee friend
    self.followees << friend unless followee_ids.include? friend.id
    refresh_browser friend
  end

  def delete_followee f
    browser.delete_selected
    followees.delete f
    save
  end
  
  def role
    self.role_symbols.first.to_s
  end
  
  # Return the list of recipes owned by the user, optionally including every recipe they've touched. Options:
  # :all => include touched recipes, not just those that have been collected
  # :sort_by = :collected => order recipes by when they were collected (as opposed to recently touched)
  # :status => Select for recipes with this status or lower
  # :public => Only public recipes
  def recipe_ids_g options={}
    constraints = {:user_id => id}
    constraints[:in_collection] = true unless options[:all]
    constraints[:status] = 1..options[:status] if options[:status]
    constraints[:private] = false if options[:public]
    ordering = (options[:sort_by] == :collected) ? "created_at" : "updated_at"
    collection = Rcpref.where(constraints).order(ordering+" DESC").select("recipe_id").map(&:recipe_id)
    if channel?
      collection << tags.collect { |tag| # For a channel, we merge all the recipes from all the associated tags
        tag.taggings.where(entity_type: "Recipe").map(&:entity_id)
      }
      collection.flatten.uniq
    else
      collection
    end
  end
  
  # This override means that all taggings are owned by super, visible to all users
  def tag_owner
    User.super_id
  end

=begin
  # Wrap the tags and tag_ids accessor methods to eliminate sensitivity to the userid, deferring to super
  alias_method :original_tags, :tags
  def tags(uid=nil)
    original_tags User.super_id
  end

  # Wrap the tags and tag_ids methods to eliminate sensitivity to the userid, deferring to super
  alias_method :original_tags=, :tags=
  def tags=(vals, uid=nil)
    original_tags= vals, User.super_id
  end

  alias_method :original_tag_ids, :tag_ids
  def tag_ids(uid=nil)
    original_tag_ids User.super_id
  end

  alias_method :original_tag_ids=, :tag_ids=
  def tag_ids=(vals, uid=nil)
    original_tag_ids= vals, User.super_id
  end
=end

private
  @@leasts = {}
  def self.least_email(str)
      @@leasts[str] || 
      (@@leasts[str] = User.where("email like ?", "%#{str}%").collect { |match| match.id }.min)
  end
  
  # Start an invited user off with two friends: the person who invited them (if any) and 'guest'
  def initialize_friends
      # Give him friends
      f = [User.guest_id, User.least_email("upstill"), User.least_email("arrone") ]
      f << self.invited_by_id if self.invited_by_id
      self.followee_ids = f
      self.save
      
      # Make the inviter follow the newbie. 
      if self.invited_by_id
          begin
              invited_by = User.find(self.invited_by_id)
              invited_by.followees << self
          rescue
          end
      end
  end
public

  def follows? (user)
    if self.class == user.class
      self.followees.include? user
    else
      self.followee_ids.include? user
    end
  end
  
  # Presents a hash of IDs with a switch value for whether to include that followee
  def followee_tokens=(flist)
    newlist = []
    flist.each_key do |key| 
        newlist.push key.to_i if (flist[key] == "1")
    end
    self.followee_ids = newlist
  end
  
  # Presents a hash of IDs with a switch value for whether to include that followee
  def subscription_tokens=(flist)
    newlist = []
    flist.each_key do |key| 
        newlist.push key.to_i if (flist[key] == "1")
    end
    self.feed_ids = newlist
  end
  
  # Is a user a channel, as opposed to a human user?
  def channel?
    self.channel_referent_id > 0
  end

  # Who does this user follow? 
  # Return either friends or channels, depending on 'channel' parameter
  def follows channel=false
    self.followees.find_all { |user| (user.channel? == channel) }
  end

  # Establish the relationship among role_id values, symbols and user-friendly names
  @@Roles = TypeMap.new( {
      guest: ["Guest", 1], 
      user: ["User", 2], 
      moderator: ["Moderator", 3], 
      editor: ["Editor", 4], 
      admin: ["Admin", 5]
  }, "unclassified")

  def role_symbols
      [@@Roles.sym(role_id)]
  end
  
  def qa
      # Ensure that everyone gets a role
      self.role_id = @@Roles.num(:user) unless self.role_id && (self.role_id > 0)
      # Handle the case where email addresses come in the form 'realworlname <email>' by
      # stripping out the excess and sticking it in the Full Name field. This is important not 
      # only to capture that information, but to avoid email collisions in the case where the
      # email portions are the same and they differ only in the real name.
      if self.email =~ /(.*)<(.*)>\s*$/ 
          uname = $1
          em = $2
          # If it's a valid email, use that for the email field
          if em =~ /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i
              self.email = em 
              self.fullname = uname.strip.titleize if self.fullname.blank?
          end
      end
  end
  
  has_many :authentications, :dependent => :destroy
  # Pass info from an authentication onto a user as needed
  @@AuthenticationMappings = {
      'facebook' => { :fullname => 'name' },
      'google_oauth2' => { },
      'twitter' => { },
      'aol' => { },
      'open_id' => { },
      'yahoo' => { },
  }

  def apply_omniauth(omniauth)
    def get_attribute_from_omniauth(attrname, uiname=nil)
      uiname ||= attrname.to_s
      instance_variable_set(attrname, omniauth['info'][uiname]) if instance_variable_get(attrname).blank? unless omniauth['info'][uiname].blank?
    end
    if oi = omniauth['info']
      mapping = @@AuthenticationMappings[omniauth['provider']]
      [:email, :image, :username, :fullname, :first_name, :last_name].each do |attrname|
        uiname = mapping[attrname] || attrname.to_s
        write_attribute(attrname, oi[uiname]) if read_attribute(attrname).blank? unless oi[uiname].blank?
      end
      extend_fields
    end
  end

  # Fill in blank fields from existing ones
  def extend_fields
    if username.blank?
      # Synthesize a unique username from the email address or fullname
      n = 0
      startname = handle if (startname = email.sub(/@.*/, '')).blank?
      self.username = startname
      until (User.where(username: username).empty?) do
        n += 1
        self.username = startname+n.to_s
      end
    end
    # Provide a random password if none exists already
    self.password = email if password.blank? # (0...8).map { (65 + rand(26)).chr }.join
    self.fullname = "#{first_name} #{last_name}" if fullname.blank? && !(first_name.blank? || last_name.blank?)
  end

  def password_required?
    (self.channel_referent_id==0) && (authentications.empty? || !password.blank?) # && super
  end
  
  # We don't require an email for users representing channels
  def email_changed?
      (self.channel_referent_id==0) && super
  end
  
  # ownership of tags restrict visible tags
  has_many :tag_owners
  has_many :tags, :through=>:tag_owners
  
  validates :email, :presence => true

  # validates_presence_of :username
  # validates_uniqueness_of :username, allow_blank: true
  # validates_format_of :username, :allow_blank => true, :with => /\A[-\w\s\.!_@]+\z/i, :message => "can't take funny characters (letters, spaces, numbers, or .-!_@ only)"
  validates_each :username do |user, attribute, value|
    # The name must be unique within channels and within users, but not across the two, i.e. it's
    # okay to have a channel named 'upstill'
    unless value.blank?
      query = user.channel ? "channel_referent_id > 0" : "channel_referent_id = 0"
      query << " and username = ?"
      query << " and id != #{user.id}" if user.id
      other = User.where query, value
      user.errors[:username] << %Q{is already taken by another #{user.channel ? "channel" : "user"}} unless other.empty?
      user.errors[:username] << "can't take funny characters. Letters, spaces, numbers, and/or .-!_@ only, please" unless value.match /\A[-\w\s\.!_@]+\z/i
    end

  end

  validates_uniqueness_of :email, :if => :email_changed?
  validates_format_of :email, :allow_blank => true, :with => /\A[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}\z/i

  before_save :qa

  # Make sure we have this particular user (who had better be in the seed list)
  def self.by_name (name)
      begin
          self.where("username = ?", name.to_s).first
      rescue Exception => e
          nil
      end
  end
  
  # Return a 2-array of 1) the list of possible roles, and 2) the current role,
  # suitable for passing to options_for_select
  def role_select
    @@Roles.list
  end

  # Class variable @@Super_user saves the super User
  @@Super_user = nil
  def self.super_id
      (@@Super_user || (@@Super_user = self.by_name(:super))).id
  end
  
  # Class variable @@Guest_user saves the guest User
  @@Guest_user = nil  
  def self.guest
      @@Guest_user || (@@Guest_user = self.by_name(:guest))
  end
      
  # Simply return the id of the guest
  def self.guest_id
      self.guest.id
  end
  
  @@Special_ids = []
  # Approve a user id for visibility by the public
  def self.public? (id)
      @@Special_ids = [self.super_id] if @@Special_ids.empty?
      !@@Special_ids.include? id
  end
  
  def self.isPrivate id
      @@Special_ids = [self.super_id] if @@Special_ids.empty?
      @@Special_ids << [id]
  end
  
  def guest? 
    id == User.guest.id
  end
  
  # Return the string by which this user is referred. Preferentially return (in order)
  # -- username
  # -- fullname
  # -- email
  def handle
    @handle ||=
      (username unless username.blank?) ||
      (fullname unless fullname.blank?) ||
      ("#{first_name} #{last_name}" unless (first_name.blank? && last_name.blank?)) ||
      email.sub(/@.*/, '')
  end
  
  def polite_name
    @polite_name ||=
        (fullname unless fullname.blank?) ||
        ("#{first_name} #{last_name}" unless (first_name.blank? && last_name.blank?)) ||
        (username unless username.blank?) ||
        email.sub(/@.*/, '')
  end

  def salutation
    (first_name unless first_name.blank?) ||
    (fullname.split(/\b/).first unless fullname.blank?) ||
    username
  end
  
  # 'name' is just an alias for handle, for use by Channel referents
  def name
    handle
  end
  
  # Who is eligible to be
  def friend_candidates(for_channels)
    User.all.keep_if { |other| 
        (for_channels == other.channel?) && # Select for channels or regular users
         User.public?(other.id) && # Exclude invisible users
         (other.channel? || (other.sign_in_count && (other.sign_in_count > 0))) && # Excluded unconfirmed invites
         (other.id != id) # Don't include this user
    }
  end

  def invitee_tokens=(tokenstr)
    @invitee_tokens = tokenstr.blank? ? [] : TokenInput.parse_tokens(tokenstr)
  end

  def channel_tokens=(tokenstr)
    @channel_tokens = tokenstr.blank? ? [] : TokenInput.parse_tokens(tokenstr)
  end

  # Return a list of my friends who match the input text
  def match_friends(txt, is_channel=nil)
    re = Regexp.new(txt, Regexp::IGNORECASE) # Match any embedded text, independent of case
    channel_constraint = is_channel ? "channel_referent_id > 0" : "channel_referent_id = 0"
    (is_channel ? User.all : followees).where(channel_constraint).select { |other|
      re.match(other.username) || re.match(other.fullname) || re.match(other.email)
    }
  end

  def issue_instructions(what = :invitation_instructions, opts={})
    # send_devise_notification(what, opts)
    self.update_attribute :invitation_sent_at, Time.now.utc unless self.invitation_sent_at
    generate_invitation_token! unless @raw_invitation_token
    send_devise_notification(what, @raw_invitation_token, opts)
  end
  
=begin
  def send_devise_notification(notification, opts={})
    devise_mailer.send(notification, self, opts).deliver
  end
=end
 
  def headers_for(action)
    inviter = User.find invited_by_id
    case action
    when :invitation, :invitation_instructions
      { 
        :subject => invitation_issuer+" wants to get you cooking.",
        :from => invitation_issuer+" on RecipePower <#{inviter.email}>",
        :reply_to => inviter.email
      }
    when :sharing_notice, :sharing_invitation_instructions
      { 
        :subject => invitation_issuer+" has something tasty for you.",
        :from => invitation_issuer+" on RecipePower <#{inviter.email}>",
        :reply_to => inviter.email
      }
    else
      {}
    end
  end  
  
  # Notify self of an event, possibly (if profile allows) sending email
  def notify( notification_type, source_user, options={})
    notification = post_notification(notification_type, source_user, options)
    if true # XXX User's profile approves
      # Mapping from notification types to email types
      case notification_type
      when :share_recipe
        self.shared_recipe = options[:what]
        msg = RpMailer.sharing_notice(notification)
        msg.deliver
      when :make_friend
        :friend_notice
      end
    end
  end
  
  # Post a notification event without sending email
  def post_notification( notification_type, from = nil, options={})
    attributes = { 
      :info => options, 
      :source_id => from.id, 
      :target_id => id, 
      :typenum => notification_type,
      :accepted => false
    }
    attributes[:source_id] = from.id if from
    notification = Notification.create( attributes )
    self.notifications_received << notification
    notification
  end

  # Users can be merged if their channels merge
  def merge other_user
    self.image = other_user.image unless image
    self.about = other_user.about unless about.blank?
    other_user.followers.each { |follower| self.followers << follower }
    other_user.followees.each { |followee| self.followees << followee }
    other_user.recipes.each { |recipe| recipe.touch true, self }
    save
  end

=begin
  # Return a list of username/id pairs suitable for popup selection
  # owner: the id that should be hidden under "Choose Another"
  # user: the id that should be excluded from the list
  # :friends=>true to include friends
  # :circles=>true to include cooking circles
  # NB labels "guest" as "all recipes"
  def self.selectionlist(*args)
	owner_id = args[0][:owner_id]
	user_id = args[0][:user_id]
	# XXX Should be more discriminating :-)
  	arr = self.find(:all).map { |user| [user.handle, user.id] }
	# Remove entries for owner and user
	exclusions = [  user_id, owner_id, self.super_id, self.guest_id ]
	arr.delete_if { |entry| exclusions.include? entry[1] }

	# Add back in the owner, under "Pick Another Collection"
	arr.unshift ["Pick Another Collection", owner_id]
  end
=end

  private
end

require "type_map.rb"

class User < ActiveRecord::Base
  include Collectible
  # Keep an avatar URL denoted by the :image attribute and kept as :thumbnail
  picable :image, :thumbnail

  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :timeoutable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable #, :validatable,
         :lockable # , :omniauthable
  after_invitation_accepted :initial_setup
  # before_save :serialize_browser

  # Setup accessible (or protected) attributes for your model
  attr_accessible :id, :username, :first_name, :last_name, :fullname, :about, :login, :private, :skip_invitation, :thumbnail_id,
                :email, :password, :password_confirmation, :invitee_tokens, :channel_tokens, :avatar_url, # :image,
                :invitation_token, :invitation_message, :invitation_issuer, :shared_type, :shared_id,
                :remember_me, :role_id, :sign_in_count, :followee_tokens, :subscription_tokens
  # attr_writer :browser
  attr_readonly :count_of_collection_pointers
  attr_accessor :invitee_tokens, :channel_tokens, :raw_invitation_token, :avatar_url,
                :shared_type, :shared_id # Kept temporarily during sharing operations
  
  has_many :notifications_sent, :foreign_key => :source_id, :class_name => "Notification", :dependent => :destroy
  has_many :notifications_received, :foreign_key => :target_id, :class_name => "Notification", :dependent => :destroy

  has_many :follower_relations, :foreign_key=>"followee_id", :dependent=>:destroy, :class_name=>"UserRelation"
  has_many :followers, -> { uniq }, :through => :follower_relations, :source => :follower

  has_many :followee_relations, :foreign_key => "follower_id", :dependent=>:destroy, :class_name => "UserRelation"
  has_many :followees, -> { uniq }, :through => :followee_relations, :source => :followee

  has_many :answers
  has_many :questions, :through => :answers

  # Channels are just another kind of user. This field (channel_referent_id, externally) denotes such.
  # TODO: delete channel_referent_id and tables feeds_users, lists_users and private_subscriptions
  belongs_to :channel, :class_name => "Referent", :foreign_key => "channel_referent_id"

  has_and_belongs_to_many :feed_collections, :join_table => "feeds_users", class_name: "Feed"
  has_and_belongs_to_many :list_collections, :join_table => "lists_users", class_name: "List"

  # NB: this stays; it represents a user's ownership of lists
  has_many :owned_lists, :class_name => "List", :foreign_key => :owner_id

  has_many :votings, :class_name => "Vote", dependent: :destroy

  has_many :collection_pointers, -> { where(in_collection: true) }, :dependent => :destroy, :class_name => "Rcpref"
  has_many :touched_pointers, :dependent => :destroy, :class_name => "Rcpref"
  # We allow users to collect users, but the collectible class method can't be used on self, so we define the association directly
  has_many :users, :through=>:collection_pointers, :source => :entity, :source_type => User, :autosave=>true
  # has_many :recipes, :through=>:collection_pointers, :source => :entity, :source_type => "Recipe", :autosave=>true
  # Class method to define instance methods for the collectible entities: those of collectible_class
  # This is invoked by the Collectible module when it is included in a collectible class
  def self.collectible collectible_class

    asoc_name = collectible_class.to_s.pluralize.underscore
    has_many asoc_name.to_sym, :through=>:collection_pointers, :source => :entity, :source_type => collectible_class, :autosave=>true
    has_many ("touched_"+asoc_name).to_sym, :through=>:touched_pointers, :source => :entity, :source_type => collectible_class, :autosave=>true
  end

  # The User class defines collectible-entity association methods here. The Collectible class is cocnsulted, and if it has
  # a :user_pointers method (part of the Collectible module), then the methods get defined, otherwise we punt
  # NB All the requisite methods will have been defined IF the collectible's class has been defined (thank you, Collectible)
  # We're really only here to deal with the case where the User class (or a user model) has been accessed before the
  # Collectible class has been defined. Thus, the method_defined? call on the collectible class is enough to ensure the loading
  # of that class, and hence the defining of the access methods.
  def method_missing(meth, *args, &block)
    meth = meth.to_s
    collectible_class = active_record_class_from_association_method_name meth
    begin
      if collectible_class.method_defined?(:user_pointers) && User.method_defined?(meth)
        self.method(meth).call *args, &block
      else
        # puts "Failed to define method '#{meth}'"
        super
      end
    rescue Exception => e
      # puts "D'OH! Couldn't create association between User and #{collectible_class}"
      super
    end
  end

  def vote entity, up=true
    Vote.vote entity, up, self
  end

  # Include the entity in the user's collection
  def collect entity
    touch entity, true
  end

  def collected? entity
    collection_pointers.exists? user: self, entity: entity
  end

  def uncollect entity
    collection_pointers.where(entity: entity).map(&:uncollect)
  end

  # Return the set of entities of a given type that the user has collected, as visible to some other
  def collected_entities entity_type, viewer=nil
    entity_type = entity_type.to_s
    if viewer == self
      assoc = entity_type.to_s
      scope = self.method(assoc).call
      scope = scope.where.not(owner_id: id) if entity_type == "List"
      scope
    else
      arr = collection_pointers.where(entity_type: entity_type, private: false).map(&:entity)
      arr = arr.keep_if { |l| l.owner != self } if entity_type == "List"
      arr
    end
  end

  # Return the set of lists visible to the given other (or public lists otherwise)
  def visible_lists other=nil
    owned_lists.where availability: ((other && other.follows?(self)) ? [0,1] : 0)
  end

  # Remember that the user has (recently) touched the entity, optionally adding it to the collection
  def touch entity=nil, collect=false
    return super unless entity
    ref = touched_pointers.create_with(in_collection: collect).find_or_initialize_by user_id: id, entity_type: entity.class.to_s, entity_id: entity.id
    if ref.created_at # Existed prior
      if (Time.now - ref.created_at) > 5
        ref.created_at = ref.updated_at = Time.now
        ref.in_collection ||= collect
        Rcpref.record_timestamps=false
        ref.save
        Rcpref.record_timestamps=true
      elsif collect && !ref.in_collection # Just touch if previously saved
        ref.in_collection = true
        ref.save
      else
        ref.touch
      end
    else # Just save the reference
      ref.save
    end
  end

  # TODO: remove collections after they've been migrated to lists
#  has_many :private_subscriptions, -> { order "priority ASC" }, :dependent=>:destroy
#  has_many :collection_tags, :through => :private_subscriptions, :source => :tag, :class_name => "Tag"
  
  # login is a virtual attribute placeholding for [username or email]
  attr_accessor :login

  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def add_followee friend
    self.followees << friend unless followee_ids.include? friend.id
    # refresh_browser friend
    save
  end

  def delete_followee f
    # browser.delete_selected
    followees.delete f
    save
  end

  def role
    self.role_symbols.first.to_s
  end

  # Scope for items from the user's collection. Options:
  # :in_collection: whether they're collected or just viewed
  # :private: limited to the user
  # :limit, :offset slicing the selection
  # :entity_type for a particular type of entity
  # :order can name any field to sort by
  # :sort_by either :collected or :viewed if :order not provided
  # :direction passes through to SQL; can be ASC or DESC
  def collection_scope options={}
    scope = Rcpref.where(
        options.slice(
            :in_collection, :private, :entity_type).merge( user_id: id )
    )
    scope = scope.where.not(entity_type: ["List", "Feed"]) unless options[:entity_type] # Exclude Feeds and Lists b/c we have a
    # The order field can be specified directly with :order, or implicitly with :collected
    unless ordering = options[:order]
      case options[:sort_by]
        when :collected
          ordering = "created_at"
        when :viewed
          ordering = "updated_at"
      end
    end
    scope = scope.order("#{ordering} #{options[:direction] || 'DESC'}") if ordering
    scope = scope.limit(options[:limit]) if options[:limit]
    scope = scope.offset(options[:offset]) if options[:offset]
    scope
  end

  # Get the number of entities of a given type (or all types) in self's collection
  def collection_size entity_type=nil
    constraints = {  }
    entity_type ?
        collection_pointers.where(entity_type: entity_type.to_s, private: false).size :
        self.count_of_collecteds
  end

private
  @@leasts = {}
  def self.least_email(str)
      @@leasts[str] ||
      (@@leasts[str] = User.where("email like ?", "%#{str}%").collect { |match| match.id }.min)
  end

  # Start an invited user off with two friends: the person who invited them (if any) and 'guest'
  def initial_setup
      # Give him friends
      f = [User.least_email("upstill"), User.least_email("arrone"), User.super_id ]
      f << self.invited_by_id if self.invited_by_id
      self.followee_ids = f

      # Give him some lists  "Keepers", "To Try", "Now Cooking"
      List.assert "Keepers", self, create: true
      List.assert "To Try", self, create: true
      List.assert "Now Cooking", self, create: true

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

  # TODO: eliminate channel? method
  # Is a user a channel, as opposed to a human user?
  def channel?
    self.channel_referent_id > 0
  end

  # TODO: replace follows method with straight followees
  # Who does this user follow?
  # Return either friends or channels, depending on 'channel' parameter
  def follows channel=false
    followees.find_all { |user| (user.channel? == channel) }
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
      # Get the user's image, replacing it if possible
      uiname = mapping[:image] || "image"
      unless imgdata || oi[uiname].blank? || ((image||"") == oi[uiname])
        self.image = oi[uiname]
        # While we're here, fetch the image data as a thumbnail
        thumbnail.perform if thumbnail # Fetch the user's thumbnail data while the authorization is fresh
      end
      [:email, :username, :fullname, :first_name, :last_name].each do |attrname|
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
    (self.channel_referent_id==0) && (authentications.empty? || !password.blank?)
  end

  # We don't require an email for users representing channels
  def email_changed?
      (self.channel_referent_id==0) && super
  end

  # ownership of tags restrict visible tags
  has_many :tag_owners
  has_many :private_tags, :through=>:tag_owners, :source => :tag, :class_name => "Tag"

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
  def self.by_name name
    self.where(username: name.to_s).first
  end

  # Return a 2-array of 1) the list of possible roles, and 2) the current role,
  # suitable for passing to options_for_select
  def role_select
    @@Roles.list
  end

  # Class variable @@Super_user saves the super User
  @@Super_user = nil
  def self.super_id
      (@@Super_user || (@@Super_user = (self.by_name(:super) || self.by_name("RecipePower")))).id
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
      when :share
        self.shared = options[:what]
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

  # Absorb another user into self
  def absorb other
    self.about = other.about if self.about.blank?
    other.touched_pointers.each { |ref| touch ref.entity, ref.in_collection }
    other.followees.each { |followee| self.add_followee followee }
    other.followers.each { |follower| follower.add_followee self }
    other.votings.each { |voting| vote(voting.entity, voting.up) } # Transfer all the other's votes
    super
  end

  # Provide the resource being shared, stored (but not saved) as a polymorphic object description
  def shared
    if !@shared_type.blank? && @shared_id
      @shared_type.constantize.find( @shared_id.to_i) rescue nil
    end
  end

  def shared= entity
    @shared_type, @shared_id = entity ? [ entity.class.to_s, entity.id ] : []
  end

  private
end

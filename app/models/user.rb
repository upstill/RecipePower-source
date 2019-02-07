require 'type_map.rb'
require 'rp_event.rb'

class User < ApplicationRecord

  # We keep the currently-logged-in user for reference by models
  def self.current
    Thread.current[:user] ||= (User.first if Rails.env.test?)
  end

  # This must be set by the controller
  def self.current=(user)
    Thread.current[:user] = user
  end

  # Get the id of the current user, if any
  def self.current_id
    self.current.id if self.current
  end

  # Am I the current user?
  def current?
    self.id && (User.current_id == self.id)
  end

  # For situations where we MUST have a user, fall back on the guest
  def self.current_or_guest
    self.current || self.guest
  end
  # We keep a cache of rcprefs that have been accessed by a user, to
  # 1) speed up subsequent accesses
  # 2) ensure that changes to refs are saved when the entity is saved.
  # NB: this is because ActiveRecord doesn't keep a record of individual members of an association,
  # and so can't :autosave them
  before_save do
    if @cached_tps
      # We want to save rcprefs that need to be saved because they're not part of an association
      # the sign of which is they're persisted and have an entity_id
      # We save the cached refs that are newly created, under the assumption that
      @cached_tps.values.compact.each { |ref| puts "Saving Rcpref##{ref.id}" ; ref.save } # unless ref.persisted? && ref.entity_id }
      @cached_tps = {}
    end
  end

  def reload
    @cached_tps = {}
    super
  end
  
  # The users are backgroundable to mail the latest newsletter
  include Backgroundable
  backgroundable :status
#  acts_as_notifier :printable_notifier_name => :username,
#                   :printable_name => :salutation

  acts_as_target email: :email,
                 email_allowed: true,
                 batch_email_allowed: :confirmed_at,  # ...for ActivityNotifications
                 printable_name: ->(user) { user.handle }

  # Class variable @@Guest_user saves the guest User
  @@Guest_user = nil
  @@Guest_user_id = 4
  @@Super_user_id = 5

  include Taggable # Can be tagged using the Tagging model
  include Collectible
  # Keep an avatar URL denoted by the :image attribute and kept as :thumbnail
  picable :image, :thumbnail, 'default-avatar-128.png'

  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :timeoutable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable #, :validatable,
         :lockable
  validates_confirmation_of :password

  after_invitation_accepted :initial_setup
  # before_save :serialize_browser

  # Setup accessible (or protected) attributes for your model
  # attr_writer :browser
  attr_readonly :count_of_collection_pointers
  attr_accessor :invitee_tokens, :avatar_url, :mail_subject, :mail_body,
                :shared_class, :shared_name, :shared_id # Kept temporarily during sharing operations
  
  # has_one :inviter, :class_name => 'User'  Defined by Devise
  has_many :invitees, :foreign_key => :invited_by_id, :class_name => 'User'

  has_many :aliases, :foreign_key => :alias_id, :class_name => 'User'
  if Rails::VERSION::STRING[0].to_i < 5
    belongs_to :aliased_to, :foreign_key => :alias_id, :class_name => 'User'
  else
    belongs_to :aliased_to, :foreign_key => :alias_id, :class_name => 'User', optional: true
  end

  scope :legit, -> { where 'sign_in_count > 0' }

  has_many :answers
  accepts_nested_attributes_for :answers, allow_destroy: true
  has_many :questions, :through => :answers

  has_many :tag_selections
  accepts_nested_attributes_for :tag_selections, allow_destroy: true

  # NB: this stays; it represents a user's ownership of lists
  has_many :owned_lists, :class_name => 'List', :foreign_key => :owner_id

  has_many :owned_taggings, :class_name => 'Tagging', :dependent => :destroy
  has_many :owned_tags, :through => 'Tagging', :class_name => 'Tag'

  has_many :votings, :class_name => 'Vote', dependent: :destroy

  # collection_pointers are Rcprefs for entities in this user's collection
  has_many :collection_pointers, -> { where(in_collection: true) }, :dependent => :destroy, :class_name => 'Rcpref'

  # ALL Rcprefs, including those that have only been touched
  has_many :touched_pointers, :dependent => :destroy, :class_name => 'Rcpref'

  # The rcprefs that are visible by others (the public portion of the collection)
  has_many :public_pointers, -> { where(in_collection: true, private: false) }, :class_name => 'Rcpref'

  # We allow users to collect users, but the collectible class method can't be used on self, so we define the association directly
  has_many :followees, :through=>:collection_pointers, :source => :entity, :source_type => 'User', :autosave=>true

  # has_many :recipes, :through=>:collection_pointers, :source => :entity, :source_type => 'Recipe', :autosave=>true
  # Class method to define instance methods for the collectible entities: those of collectible_class
  # This is invoked by the Collectible module when it is included in a collectible class
  def self.collectible collectible_class
    collectible_class_name = collectible_class.name
    asoc_name = collectible_class_name.pluralize.underscore
    has_many asoc_name.to_sym, :through=>:collection_pointers, :source => :entity, :source_type => collectible_class_name, :autosave=>true
    has_many ('touched_'+asoc_name).to_sym, :through=>:touched_pointers, :source => :entity, :source_type => collectible_class_name, :autosave=>true
  end

  # The User class defines collectible-entity association methods here. The Collectible class is consulted, and if it has
  # a :collector_pointers method (part of the Collectible module), then the methods get defined, otherwise we punt
  # NB All the requisite methods will have been defined IF the collectible's class has been defined (thank you, Collectible)
  # We're really only here to deal with the case where the User class (or a user model) has been accessed before the
  # Collectible class has been defined. Thus, the method_defined? call on the collectible class is enough to ensure the loading
  # of that class, and hence the defining of the access methods.
  def method_missing(meth, *args, &block)
    meth = meth.to_s
    begin
      collectible_class = active_record_class_from_association_method_name meth
      if collectible_class.method_defined?(:collector_pointers) && User.method_defined?(meth)
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

  def uncollect entity
    touch entity, false
  end

  # Remember that the user has (recently) touched the entity, optionally adding it to or removing it from the collection
  def touch entity=nil, and_collect=nil
    return super unless entity
    return true if entity == self || !entity.is_a?(Collectible) # We don't collect or touch ourself
    # entity.be_touched id, and_collect
    cached_tp(true, entity) do |cr|
      if and_collect.nil?
        cr.touch if cr.persisted? # Touch will effectively happen when it's saved
      else
        cr.in_collection = and_collect
      end
    end
  end

  # When a rcpref that involves the user is created, add it to the association(s)
  def update_associations ref
    self.touched_pointers << ref unless ref.entity == self
  end

  # login is a virtual attribute placeholding for [username or email]
  attr_accessor :login

  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(['lower(username) = :value OR lower(email) = :value', { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def role
    self.role_symbols.first.to_s
  end

  def self.strscopes matcher
    onscope = block_given? ? yield() : self.unscoped
    [
        onscope.where('"users"."username" ILIKE ?', matcher),
        onscope.where('"users"."fullname" ILIKE ?', matcher),
        onscope.where('"users"."email" ILIKE ?', matcher),
        onscope.where('"users"."first_name" ILIKE ?', matcher),
        onscope.where('"users"."last_name" ILIKE ?', matcher),
        onscope.where('"users"."about" ILIKE ?', matcher)
    ]
  end

  # Scope for items from the user's collection. Options:
  # :in_collection: whether they're collected or just viewed
  # :private: limited to the user
  # :limit, :offset slicing the selection
  # :entity_type for a particular type of entity
  # OBSOLETE :order can name any field to sort by
  # OBSOLETE :sort_by either :collected or :viewed if :order not provided
  # OBSOLETE :direction passes through to SQL; can be ASC or DESC
  def collection_scope options={}
    scope = Rcpref.where(
        options.slice(
            :in_collection, :private, :entity_type).merge( user_id: id )
    )
    scope = scope.where.not(entity_type: %w{ List Feed }) unless options[:entity_type] # Exclude Feeds and Lists b/c we have a
    # The order field can be specified directly with :order, or implicitly with :collected
=begin
    # This is now handled at a different level
    unless ordering = options[:order]
      case options[:sort_by]
        when :collected
          ordering = 'created_at'
        when :viewed
          ordering = 'updated_at'
      end
    end
=end
    scope = scope.order("#{options[:order]} #{options[:direction] || 'DESC'}") if options[:order]
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
      (@@leasts[str] = User.where('email like ?', "%#{str}%").collect { |match| match.id }.min)
  end

  # Start an invited user off with two friends: the person who invited them (if any) and 'guest'
  def initial_setup
    # Give him friends
    f = [User.least_email('upstill'), User.least_email('arrone'), User.super_id]
    f << self.invited_by_id if self.invited_by_id
    self.followee_ids = f

    # Give him some lists  'Keepers', 'To Try', 'Now Cooking'
    List.assert 'Keepers', self, create: true
    List.assert 'To Try', self, create: true
    List.assert 'Now Cooking', self, create: true

    self.save

    # Make the inviter follow the newbie.
    if invited_by
      invited_by.followees << self
      invited_by.save
    end
  end

  public

  # Does this user have this other user in their collection?
  def follows? (user)
    collection_pointers.exists? entity: user
  end

  # Presents a hash of IDs with a switch value for whether to include that followee
  def followee_tokens=(flist)
    newlist = []
    flist.each_key do |key|
        newlist.push key.to_i if (flist[key] == '1')
    end
    self.followee_ids = newlist
  end

  # Establish the relationship among role_id values, symbols and user-friendly names
  @@Roles = TypeMap.new( {
      guest: ['Guest', 1],
      user: ['User', 2],
      moderator: ['Moderator', 3],
      editor: ['Editor', 4],
      admin: ['Admin', 5]
  }, 'unclassified')

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
      # Catch the user up on the newsletter, except for the last published issue
      self.last_edition = (Edition.where(published: true).maximum(:id) || 1)-1 if subscribed && subscribed_changed?
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
      uiname = mapping[:image] || 'image'
      unless imgdata || oi[uiname].blank? || ((image||'') == oi[uiname])
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
    authentications.empty? || !password.blank?
  end

  # ownership of tags restrict visible tags
  has_many :tag_owners
  has_many :private_tags, :through=>:tag_owners, :source => :tag, :class_name => 'Tag'

  validates :email, :presence => true

  # validates_presence_of :username
  validates_uniqueness_of :username, allow_blank: true
  validates_format_of :username, :allow_blank => true, :with => /\A[-\w\s\.!_@]+\z/i, :message => "can't take funny characters (letters, spaces, numbers, or .-!_@ only)"

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

  def self.super_id
    @@Super_user_id
    # (@@Super_user || (@@Super_user = self.find(@@Super_user_id)) # (self.by_name(:super) || self.by_name('RecipePower')))).id
  end

  def self.superuser
    @@Super_user ||= self.find(@@Super_user_id) # by_name(:guest))
  end

  def self.super_id= id
    @@Super_user_id = id
  end

  def self.guest
    @@Guest_user ||= self.find(@@Guest_user_id) # by_name(:guest))
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

  def salutation polite=false
    (first_name unless first_name.blank?) ||
    (fullname.split(/\b/).first unless fullname.blank?) ||
    (username unless polite)
  end

  def printable_notifier_name
    username
  end

  # 'name' is just an alias for handle, for use by Channel referents
  alias_method :name, :handle

  # Who is eligible to be a followee
  # NB Currently out of use except in followees_list, which is also out of use
  def friend_candidates
    User.all.keep_if { |other|
         User.public?(other.id) && # Exclude invisible users
         (other.sign_in_count && (other.sign_in_count > 0)) && # Excluded unconfirmed invites
         (other.id != id) # Don't include this user
    }
  end

  def invitee_tokens=(tokenstr)
    @invitee_tokens = tokenstr.blank? ? [] : TokenInput.parse_tokens(tokenstr)
  end

  # Return a list of my friends who match the input text
  def match_friends txt
    re = Regexp.new(txt, Regexp::IGNORECASE) # Match any embedded text, independent of case
    followees.select { |followee|
      re.match(followee.username) || re.match(followee.fullname) || re.match(followee.email)
    }
  end

  # Absorb another user into self
  def absorb other
    self.about = other.about if self.about.blank?
    other.touched_pointers.each { |ref| ref.in_collection ? self.collect(ref.entity) : self.uncollect(ref.entity) }
    other.followees.each { |followee| self.collect followee }
    other.collectors.each { |collector| collector.collect self }
    other.votings.each { |voting| vote(voting.entity, voting.up) } # Transfer all the other's votes
    super
  end

  # Provide the resource being shared, stored (but not saved) as a polymorphic object description
  def shared
    @shared_class = @shared_class.constantize if @shared_class.is_a?(String)
    @shared_id = @shared_id.to_i if @shared_id.is_a?(String)
    @shared_class.find_by(id: @shared_id) if @shared_class && @shared_id
  end

  def shared= entity
    @shared_class, @shared_id = entity ? [ entity.class, entity.id ] : []
  end

  def perform # Do a DelayedJob task by emailing the earliest unseen Newsletter
    if edition_num = Edition.where("number > #{last_edition}").where(published: true).minimum(:number)
      edition = Edition.find_by number: edition_num
      begin
        RpMailer.newsletter(edition, self).deliver_now
        self.last_edition = edition.id
        return save
      rescue Exception => e
        return false
      end
    end
  end

  private

  # Maintain a cache of modified rcprefs by user id
  # assert: build it if it doesn't already exist
  # user_id: the user_id that identifies rcpref for this entity
  def cached_tp assert=false, entity
    unless assert == false || assert == true
      assert, user_id = false, assert
    end
    key = "#{entity.class.base_class.to_s}#{entity.id}"
    if cr = (@cached_tps ||= {})[key]
      yield(cr) if block_given?
    else
      unless @cached_tps.has_key?(key) # Nil means nil (i.e., no need to lookup the ref)
        cr = @cached_tps[key] ||
            # Try to find the ref amongst the loaded refs, if any
            (touched_pointers.loaded? && touched_pointers.find { |rr| "#{rr.entity_type}#{rr.entity_id}" == key }) ||
            touched_pointers.where(entity: entity).first
      end
      # Finally, build a new one as needed
      if cr
        yield(cr) if block_given?
      elsif assert
        cr = touched_pointers.new entity: entity
        yield(cr) if block_given?
        cr.ensconce
      end
    end
    @cached_tps[key] = cr
  end
end

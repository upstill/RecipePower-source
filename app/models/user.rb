require "type_map.rb"
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :timeoutable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :lockable # , :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :id, :username, :fullname, :about,
                :email, :password, :password_confirmation, 
                :recipes, :remember_me, :role_id, :sign_in_count, :invitation_message, :followee_tokens
=begin
  has_many :child_relations, :foreign_key=>"parent_id", :dependent=>:destroy, :class_name=>"ReferentRelation"
  has_many :children, :through => :child_relations, :source => :child, :uniq => true 

  has_many :parent_relations, :foreign_key => "child_id", :dependent=>:destroy, :class_name => "ReferentRelation"
  has_many :parents, :through => :parent_relations, :source => :parent, :uniq => true
=end
  has_many :follower_relations, :foreign_key=>"followee_id", :dependent=>:destroy, :class_name=>"UserRelation"
  has_many :followers, :through => :follower_relations, :source => :follower, :uniq => true 

  has_many :followee_relations, :foreign_key => "follower_id", :dependent=>:destroy, :class_name => "UserRelation"
  has_many :followees, :through => :followee_relations, :source => :followee, :uniq => true
  
  # Channels are just another kind of user. This field (channel_referent_id, externally) denotes such.
  belongs_to :channel, :class_name => "ChannelReferent"
  
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
  
  # Is a user a channel, as opposed to a human user?
  def channel?
      self.channel_referent_id > 0
  end

  # Override the followees method to allow for guests and super to see all users, and
  # to filter for whether to return the channels
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
  
  # Ensure each user has a role, defaulting to :user
  before_save do
      self.role_id = @@Roles.num(:user) unless self.role_id && (self.role_id > 0)
  end
  
  has_many :authentications, :dependent => :destroy
  # Pass info from an authentication onto a user as needed
  def apply_omniauth(omniauth)
    if ui = omniauth['info']
      self.email = ui['email'] if email.blank? && !ui['email'].blank?
      self.image = ui['image'] if image.blank? && !ui['image'].blank?
      self.username = ui['nickname'] if username.blank? && !ui['nickname'].blank?
      self.fullname = ui['name'] if fullname.blank? && !ui['name'].blank?
    end
  end

  def password_required?
    (self.channel_referent_id==0) && (authentications.empty? || !password.blank?) && super
  end
  
  # We don't require an email for users representing channels
  def email_changed?
      (self.channel_referent_id==0) && super
  end
  
  # ownership of tags restrict visible tags
  has_many :tag_owners
  has_many :tags, :through=>:tag_owners

  has_many :rcprefs
  has_many :recipes, :through=>:rcprefs, :autosave=>true

  validates_presence_of :username
  validates_uniqueness_of :username
  validates_uniqueness_of :email, :if => :email_changed?
  validates_format_of :username, :allow_blank => true, :with => /^[-\w\s\.!_@]+$/i, :message => "can't take funny characters (letters, spaces, numbers, or .-!_@ only)"
  validates_format_of :email, :allow_blank => true, :with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i

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
      [@@Roles.list, role_id]
  end

  # Class variable @@Super_user saves the super user_id
  @@Super_user = nil
  def self.super_id
      (@@Super_user || (@@Super_user = self.by_name(:super))).id
  end
  
  # Class variable @@Guest_uid saves the guest user_id
  @@Guest_user = nil  
  def self.guest
      @@Guest_user || (@@Guest_user = self.by_name(:guest))
  end
      
  def self.guest_id
      self.guest.id
  end
  
  @@Special_ids = []
  # Approve a user id for visibility by the public
  def self.public? (id)
      @@Special_ids = [self.super_id, self.guest_id] if @@Special_ids.empty?
      !@@Special_ids.include? id
  end
  
  def self.isPrivate id
      @@Special_ids = [self.super_id, self.guest_id] if @@Special_ids.empty?
      @@Special_ids << [id]
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
  	arr = self.find(:all).map { |user| [user.username, user.id] }
	# Remove entries for owner and user
	exclusions = [  user_id, owner_id, self.super_id, self.guest_id ]
	arr.delete_if { |entry| exclusions.include? entry[1] }

	# Add back in the owner, under "Pick Another Collection"
	arr.unshift ["Pick Another Collection", owner_id]
  end
=end

  private

  # Look up user by id and return the name, protecting against 
  # invalid ids
  def self.uname(id)
      if id && (id > 0) && (user = self.find(id))
         user.username
      else
         "no user"
      end
  end
end

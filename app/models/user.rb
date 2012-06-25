require "type_map.rb"
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :timeoutable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable # , :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :id, :username, :email, :password, :password_confirmation, :recipes, :remember_me, :role_id, :sign_in_count

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
  
  has_many :authentications
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
    (authentications.empty? || !password.blank?) && super
  end
  
  # ownership of tags restrict visible tags
  has_many :tag_owners
  has_many :tags, :through=>:tag_owners

  has_many :rcprefs
  has_many :recipes, :through=>:rcprefs, :autosave=>true

  validates_presence_of :username
  validates_uniqueness_of :username, :email
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

# Robustly get the record for the current user, or guest if not logged in
  def self.current (uid)
      begin
          self.find (uid || self.guest_id)
      rescue ActiveRecord::RecordNotFound => e
      end
  end

  # Class variable @@Super_user saves the super user_id
  @@Super_user = nil
  def self.super_id
      (@@Super_user || (@@Super_user = self.by_name(:super))).id
  end
  
  # Class variable @@Guest_uid saves the guest user_id
  @@Guest_user = nil
  def self.guest_id
      (@@Guest_user || (@@Guest_user = self.by_name(:guest))).id
  end

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

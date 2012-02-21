class User < ActiveRecord::Base
    
    # ownership of tags restrict visible tags
    has_many :tag_owners
    has_many :tags, :through=>:tag_owners

  # Class variable @@Super_user saves the super user_id
  @@Super_user = nil

  def self.super_id
     unless @@Super_user
        @@Super_user =  self.where("username = ?", :super).first ||
           		self.new(:username => :super, 
				 :password=>"Sk4pcL2u",
				 :email=>"webmaster@recipepower.com")
	    @@Super_user.save
     end
     @@Super_user.id
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

	# Add back in the owner, under "Pick Another List"
	arr.unshift ["Pick Another List", owner_id]
  end

  # Class variable @@Guest_user saves the guest user_id
  @@Guest_user = nil

  def self.guest_id
     unless @@Guest_user
        @@Guest_user =  self.where("username = ?", :guest).first ||
           		self.new(:username => :guest)
	@@Guest_user.save(:validate=>false)
     end
     @@Guest_user.id
  end

  has_many :rcprefs
  has_many :recipes, :through=>:rcprefs, :autosave=>true

  # new columns need to be added here to be writable through mass assignment
  attr_accessible :username, :email, :password, :password_confirmation, :recipes

  attr_accessor :password
  before_save :prepare_password

  validates_presence_of :username
  validates_uniqueness_of :username, :email, :allow_blank => true
  validates_format_of :username, :with => /^[-\w\._@]+$/i, :allow_blank => true, :message => "should only contain letters, numbers, or .-_@"
  validates_format_of :email, :with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i
  validates_presence_of :password, :on => :create
  validates_confirmation_of :password
  validates_length_of :password, :minimum => 4, :allow_blank => true

  # login can be either username or email address
  def self.authenticate(login, pass)
    user = find_by_username(login) || find_by_email(login)
    return user if user && user.password_hash == user.encrypt_password(pass)
  end

  def encrypt_password(pass)
    BCrypt::Engine.hash_secret(pass, password_salt)
  end

  private

  def prepare_password
    unless password.blank?
      self.password_salt = BCrypt::Engine.generate_salt
      self.password_hash = encrypt_password(password)
    end
  end

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

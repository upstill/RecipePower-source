class User < ActiveRecord::Base
    
    # ownership of tags restrict visible tags
    has_many :tag_owners
    has_many :tags, :through=>:tag_owners

    has_many :rcprefs
    has_many :recipes, :through=>:rcprefs, :autosave=>true

    # new columns need to be added here to be writable through mass assignment
    attr_accessible :id, :username, :email, :password, :password_confirmation, :recipes, :password_hash, :password_salt

    attr_accessor :password
    before_save :prepare_password

    validates_presence_of :username
    validates_uniqueness_of :username, :email, :allow_blank => true
    validates_format_of :username, :with => /^[-\w\._@]+$/i, :allow_blank => true, :message => "should only contain letters, numbers, or .-_@"
    validates_format_of :email, :with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i
    validates_presence_of :password, :on => :create
    validates_confirmation_of :password
    validates_length_of :password, :minimum => 4, :allow_blank => true

    # Make sure we have this particular user (who had better be in the seed list)
    def self.by_name (name)
        begin
            self.where("username = ?", name.to_s).first
        rescue Exception => e
            nil
        end
    end

# Robustly get the record for the current user, or guest if not logged in
  def self.current (uid)
      begin
          self.find (uid || self.guest_id)
      rescue ActiveRecord::RecordNotFound => e
      end
  end

  # Class variable @@Super_uid saves the super user_id
  @@Super_uid = nil
  def self.super_id
     @@Super_uid || (@@Super_uid = self.by_name(:super).id)
  end
  
  # Class variable @@Guest_uid saves the guest user_id
  @@Guest_uid = nil
  def self.guest_id
      @@Guest_uid || (@@Guest_uid = self.by_name(:guest).id)
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

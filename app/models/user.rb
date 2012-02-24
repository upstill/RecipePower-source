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
    
    def self.seed
        debugger
        u = self.new :username => "maxgarrone@gmail.com", :email=>"maxgarrone@gmail.com", :password_hash=>"$2a$10$jDwmhYV1GCWTlh2PfogRFu1b9ztDD04ngi/WUnYvxSBJ1ohML/S8G", :password_salt=>"$2a$10$jDwmhYV1GCWTlh2PfogRFu"
        u.save :validate=>false
        u = self.new :username => "aaron", :email=>"sweetaz@gmail.com", :password_hash=>"$2a$10$2QSRHaYD8EB89FT42HF8X.3hSLB/xuAB.ryH2ucMikUGbldDgqr46"
        u.save :validate=>false
        u = self.new :username => "upstill", :email=>"steve@upstill.net", :password_hash=>"$2a$10$SlXpc.5frJuxeUA0O/t46eRgrWbBqb9D4cKIoOHM44QJnA2bVthFW", :password_salt=>"$2a$10$SlXpc.5frJuxeUA0O/t46e"
        u.save :validate=>false
   		@@Super_user = self.new :username => :super, :email=>"webmaster@recipepower.com"
   		@@Super_user.password = "Sk4pcL2u"
   		@@Super_user.save
        @@Guest_user = self.new :username => :guest
    	@@Guest_user.save :validate=>false
    end
    
    private
    # Make sure we have this particular user (who had better be in the seed list)
    def self.ensure_user (name)
        begin
            self.where("username = ?", name.to_s).first
        rescue Exception => e
            debugger
            nil
        end
    end
public

# Robustly get the record for the current user
  def self.current (uid)
      debugger
      begin
          self.find (uid || self.guest_id)
      rescue ActiveRecord::RecordNotFound => e
      end
  end

  # Class variable @@Super_user saves the super user_id
  @@Super_user = nil
  def self.super_id
     (@@Super_user || (@@Super_user = self.ensure_user(:super))).id
  end
  
  # Class variable @@Guest_user saves the guest user_id
  @@Guest_user = nil
  def self.guest_id
      (@@Guest_user || (@@Guest_user = self.ensure_user(:guest))).id
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

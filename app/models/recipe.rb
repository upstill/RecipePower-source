require './lib/Domain.rb'
require './lib/RPDOM.rb'
require 'open-uri'
require 'nokogiri'
require 'htmlentities'

class GettableURLValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
        if(attribute == :url) 
            if Site.by_link(value)
                true
            else
                record.errors.add :url, "\'#{value}\' doesn't seem to be a working URL"
                nil
            end
        end
    end
end

class Recipe < ActiveRecord::Base
  attr_accessible :tag_tokens, :title, :url, :alias, :ratings_attributes, :comment, :current_user, :status, :privacy, :picurl, :tagpane
  after_save :save_ref

  validates :title,:presence=>true 
  validates :url,  :presence=>true, :gettableURL => true

  has_many :tagrefs
  has_many :tags, :through=>:tagrefs, :autosave=>true
  attr_reader :tag_tokens
  
  has_many :ratings
  has_many :scales, :through=>:ratings, :autosave=>true, :dependent=>:destroy
  # attr_reader :ratings_attributes
  accepts_nested_attributes_for :ratings, :reject_if => lambda { |a| a[:scale_val].nil? }, :allow_destroy=>true

  validates_uniqueness_of :url

  has_many :rcprefs
  has_many :users, :through=>:rcprefs, :autosave=>true
  attr_reader :comment
  attr_reader :privacy
  attr_reader :status
  
  @@coder = HTMLEntities.new
  
  # Make the recipe title nice for display
  def trimmed_title
      ttl = self.title || ""
      if st = self.url && Site.by_link(self.url)
          ttl = st.trim_title ttl
      end
      # Convert HTML entities
      @@coder.decode ttl
  end
  
  # Before editing, try and fill in a blank title by cracking the url
  def check_title
      if self.title.blank? && st = (url && Site.by_link(self.url))
          self.title = (st.yield :Title)[:Title] || ""
          self.title = self.trimmed_title
      else
          self.title
      end
  end
  
  # Get the cached rcpref for the recipe and its current user
  def current_ref
      if(@current_user.nil?) # No user => no ref
         @current_ref = nil 
      elsif(@current_ref.nil? || 
      	    @current_ref.user_id != @current_user)
	 @current_ref = self.rcprefs.where("user_id = ?", @current_user)[0]
      end
      @current_ref
  end
  
  # The comment for a recipe comes from its rcprefs for a 
  # given user_id 
  # Get THIS USER's comment on a recipe
  def comment
    current_ref() ? @current_ref.comment : ""
  end

  # Get another user's comment on a recipe
  def comment_of_user(uid)
    unless (refs = self.rcprefs.where(:user_id=>uid)).empty? 
    	refs.first.comment 
    end
  end

  # Record THIS USER's comment in the reciperefs join table
  def comment=(str)
    @current_ref.comment = str if current_ref()
  end

  # Casual setting of privacy for the recipe: immediate save for 
  # this recipe/user combo.
  # Presented as an integer related to @@privacies
  def privacy=(val)
     @current_ref.privacy = val.to_i if current_ref()
  end

  def privacy
    current_ref() ? @current_ref.privacy : MyConstants::Rcppermission_public
  end

  # Casual setting of status for the recipe: immediate save for 
  # this recipe/user combo.
  # Presented as an integer related to @@statuses
  def status=(val)
     @current_ref.status = val.to_i if current_ref()
  end

  def status
    current_ref() ? @current_ref.status : MyConstants::Rcpstatus_misc
  end

  # An after_save method for a recipe which saves the 
  # recipe/user info cache for the current user
  def save_ref
      if(@current_ref && (@current_ref.user_id == @current_user))
          refs = self.rcprefs.where(:user_id=>@current_user)
         if(ref = refs.first)
            ref.comment = @current_ref.comment
            ref.status = @current_ref.status
            ref.privacy = @current_ref.privacy
	    ref.save
         end
      end
  end

  @@statuses = [[:Rotation, MyConstants::Rcpstatus_rotation], 
  		[:Favorites, MyConstants::Rcpstatus_favorites],
		[:Interesting, MyConstants::Rcpstatus_interesting],
		[:Misc, MyConstants::Rcpstatus_misc]]

  @@privacies = [[:Private, MyConstants::Rcppermission_private], 
  		["Friends Only", MyConstants::Rcppermission_friends],
		[:Circles, MyConstants::Rcppermission_circles],
		[:Public, MyConstants::Rcppermission_public]]

  # return an array of status/value pairs for passing to select()
  def self.status_select
      @@statuses
  end

  # return an array of status/value pairs for passing to select()
  def self.privacy_select
      @@privacies
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids
  def tag_tokens=(ids)
	# The list may contain new terms, passed in single quotes
    arr = ids.split(",").map { |e| 
        if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags
            tag = Tag.find e.to_i
        else
            e.sub!(/^\'(.*)\'$/, '\1') # Strip out enclosing quotes
            tag = Tag.strmatch(e, userid: self.current_user, assert: true)[0]
        end
        self.tags << tag unless tag.nil? || self.tags.exists?(id: tag.id)
    }
  end

  public

  def current_user
      @current_user
  end

  def current_user=(id)
      @current_user = id
  end

  # Return the number of times a recipe's been marked
  def num_cookmarks
     Rcpref.where(["recipe_id = ?", self.id]).count
  end

  # Is the recipe cookmarked by the given user?
  def marked?(uid)
      self.rcprefs.where("user_id = ?", uid).exists?
  end
  
  # Either fetch an exising recipe record or make a new one, based on the
  # params. If the params have an :id, we find on that, otherwise we look
  # for a record matching the :url. 
  # If a new recipe record needs to be created, we also do QA on the provided URL
  # Either way, we also make sure that the recipe is associated with the given user
    def self.ensure( userid, params)
        if id = params[:id]
            begin
                rcp = Recipe.find id.to_i
            rescue => e
                rcp = self.new
                rcp.errors.add :id, "There is no recipe number #{id}"
            end
        else
            url = params[:url]
            if url && Recipe.exists?(:url => url)  # Previously captured => just look it up
                rcp = Recipe.where("url = ?", url).first
            else
                rcp = Recipe.new params
                if rcp.url && site = Site.by_link(rcp.url)
                    # Find the site for this url
                    # Get the site to crack the page for this recipe
                    # Pull title, picture and canonical URL from the result
                    # rcp.url = rcp.url || (site.yield :URI, rcp.url)[:URI]
                    found = site.yield :Title, rcp.url
                    # rcp.url = rcp.url || found[:URI]
                    # We may have re-interpreted the URL from the page, so
                    # need to re-check that the recipe doesn't already exist
                    if Recipe.exists? url: rcp.url  # Previously captured 
                        Recipe.where("url = ?", rcp.url).first
                    else
                        rcp.picurl = (site.yield :Image, rcp.url)[:Image] || ""
                        rcp.title = rcp.title || found[:Title] 
                        rcp.save
                    end
                else
                    rcp.errors.add :url, rcp.url.blank? ? "must be supplied" : "doesn't make sense or can't be found"
                end
            end
        end
        # If all is well, make sure it's on the user's list
        rcp.ensureUser( userid ) if rcp.id && rcp.errors.empty?
        rcp
    end

# Return the human-readable name for the recipe's source
def sourcename
    @site = @site || Site.by_link(self.url)
    @site.name
end

# Return the URL for the recipe's source's home page
def sourcehome
    @site = @site || Site.by_link(self.url)
    @site.home
end

   # Make sure this recipe is in the collection of the current user
    def ensureUser(uid)
        unless self.users.exists?(uid)
            user = User.find(uid)
            self.users << user
            if self.save
                # Provide defaults for status and privacy
                @current_user = uid
                ref = self.current_ref
                ref.status = MyConstants::Rcpstatus_misc
                ref.privacy = MyConstants::Rcppermission_friends
                ref.save
            end
        end
    end
    
    # Set the mod time of the recipe to now (so it sorts properly in Recent lists)
    def touch
        self.updated_at = Time.now
        self.save
    end

   # This stores the edited tagpane for the recipe--or maybe not. The main
   # purpose is to parse the HTML to extract any tags embedded therein, 
   # particularly those available from the hRecipe format. These become
   # the 'robo-tags' for the recipe.
   def tagpane=(str)
       ou = Nokogiri::HTML str
       newtags = []
       oldtags = self.tag_ids
       ou.css(".name").each { |child|
            str = child.content.to_s
            # Look up the tag and/or create it
            tag = Tag.strmatch(str, self.current_user || User.guest_id, :Food, true)
            newtags << tag.id unless oldtags.include? tag.id
            x=2
       }
       if newtags.length
          self.tag_ids= oldtags + newtags
          self.save
       end
       super
   end


@@DoSpans

   # Parse the given html for tags and other keys,
   # guided by the specified class. Return a modified tree,
   # marked with that class and <possibly> with embedded subclasses.
   # NB: this is the entry point for turning HTML into a tagified 
   # form, at all levels of the tree.
   def self.parse(html, kind)
        # We use Nokogiri to get the DOM tree
        ou = Nokogiri::HTML html
        # Possible symbols taken from Google's microformats spec.
        if kind.to_sym == :hrecipe 
            # Try to parse the whole thing. Right now, we just:
            # 1) look for the 'hrecipe' tag, returning that tree if it exists
            # 2) clean up the tree, i.e., remove all tags 
            # except those which declare one of the parsing entities
            html = RPDOM.DOMstrip (ou.css(".hrecipe").first || ou), 0
            # Declare it preformatted to preserve EOLs
            html = "<pre>#{html}</pre>"
        elsif RPDOM.allowable kind.to_sym
            html = RPDOM.DOMstrip ou, 0
            html = "<span class=\"#{kind.to_s.html_safe}\">#{html}</span>"
       		# when :fn # Recipe title
       		# when :photo
       		# when :ingredients
           		# when :ingredient
	       		# when :amount
                  		# when :quantity
                  		# when :unit
               		# when :conditions
           	  		# when :condition
               		# when :name
       		# else
	       # when :recipeType  e.g., appetizer, entree, dessert
	       # when :published  ISO Date Format: http://www.w3.org/QA/Tips/iso-date
	       # when :summary
	       # when :review  Can include nested review information http://support.google.com/webmasters/bin/answer.py?answer=146645
	       
	       # See http://en.wikipedia.org/wiki/ISO_8601#Durations for ISO Duration Format
	       # when :prepTime
	       # when :cookTime
	       # when :totalTime

	       # when :nutrition
		   # "These elements are not explicitly part of the hRecipe microformat,
		   # but Google will recognize them."
		   # when :servingSize
		   # when :calories
		   # when :fat
		   # when :saturatedFat
		   # when :unsaturatedFat
		   # when :carbohydrates
		   # when :sugar
		   # when :fiber
		   # when :protein
		   # when :cholesterol 
	       # when :instructions
		   # when :instruction
	       # when :yield
	       # when :author # Can include nested Person information
       end
       # Having modified the tree, we spell it out as HTML (assuming it's not 
       # already been so expressed)
       html || ou.to_s
   end
end

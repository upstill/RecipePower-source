require './lib/Domain.rb'
require './lib/RPDOM.rb'
require 'open-uri'
require 'nokogiri'
require 'htmlentities'

class GettableURLValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
        if(attribute == :url) 
            if test_result = Site.test_link(value) # by_link(value)
                record.url = test_result if test_result.kind_of?(String)
                true
            else
                record.errors.add :url, "\'#{value}\' doesn't seem to be a valid URL (can you use it as an address in your browser?)"
                nil
            end
        elsif attribute == :picurl
            if !value || value.empty? || Site.test_link(value)
                true
            else
                # The picurl may be a relative path. In fact, it may have backup characters
                begin
                  uri = URI.join( record.url, value) 
                  record.picurl = uri.to_s
                  true
                rescue Exception => e
                    record.errors.add :picurl, "\'#{value}\' doesn't seem to be a working URL"
                    nil
                end
            end
        end
    end
end

class Recipe < ActiveRecord::Base
  attr_accessible :tag_tokens, :title, :url, :alias, :ratings_attributes, :comment, :current_user, :status, :private, :picurl, :tagpane
  after_save :save_ref

  validates :title,:presence=>true 
  validates :url,  :presence=>true, :gettableURL => true
  validates :picurl, :gettableURL => true

  has_many :tagrefs, :dependent=>:destroy
  has_many :tags, :through=>:tagrefs, :autosave=>true
  attr_reader :tag_tokens
  
  has_many :ratings, :dependent=>:destroy
  has_many :scales, :through=>:ratings, :autosave=>true
  # attr_reader :ratings_attributes
  accepts_nested_attributes_for :ratings, :reject_if => lambda { |a| a[:scale_val].nil? }, :allow_destroy=>true

  validates_uniqueness_of :url

  has_many :rcprefs, :dependent=>:destroy
  has_many :users, :through=>:rcprefs, :autosave=>true
  has_many :touches, :dependent=>:destroy
  attr_reader :comment
  attr_accessor :private, :current_user
  attr_reader :status
  
  @@coder = HTMLEntities.new
  
  # Either fetch an exising recipe record or make a new one, based on the
  # params. If the params have an :id, we find on that, otherwise we look
  # for a record matching the :url. If there are no params, just return a new recipe
  # If a new recipe record needs to be created, we also do QA on the provided URL
  # and dig around for a title.
  # Either way, we also make sure that the recipe is associated with the given user
  def self.ensure( userid, params, add_to_collection = true)
    if params.blank?
      rcp = self.new      
    elsif (id = params[:id].to_i) && (id > 0) # id of 0 means create a new recipe
      begin
        rcp = Recipe.find id
      rescue => e
        rcp = self.new
        rcp.errors.add :id, "There is no recipe number #{id.to_s}"
      end
    else # No id: create based on url
      url = params[:url]
      if url && Recipe.exists?(:url => url)  # Previously captured => just look it up
        rcp = Recipe.where("url = ?", url).first
      else
        params.delete(:rcpref)
        rcp = Recipe.new params
        # Find the site for this url
        if rcp.url && site = Site.by_link(rcp.url)
          if site.site == "http://www.recipepower.com"
            rcp.errors.add :url, "Sorry, can't cookmark pages from RecipePower. (Does that even make sense?)"
          else
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
          end
        else
          rcp.errors.add :url, rcp.url.blank? ? "must be supplied" : "doesn't make sense or can't be found"
        end
      end
    end
    # If all is well, make sure it's on the user's list
    if userid && rcp.id && rcp.errors.empty?
      rcp.touch(rcp.current_user = userid, add_to_collection)
    end
    rcp
  end
  
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

  def piclist
    Site.piclist self.url
  end

  # An after_save method for a recipe which saves the 
  # recipe/user info cache for the current user
  def save_ref
    if(@current_ref && (@current_ref.user_id == @current_user))
      refs = self.rcprefs.where(:user_id=>@current_user)
      if(ref = refs.first)
        ref.comment = @current_ref.comment
        ref.status = @current_ref.status
        ref.private = @current_ref.private
        ref.save
      end
    end
  end

  @@statuses = [
    ["Now Cooking", MyConstants::Rcpstatus_rotation], 
    [:Keepers, MyConstants::Rcpstatus_favorites],
    ["To Try", MyConstants::Rcpstatus_interesting],
    [:Misc, MyConstants::Rcpstatus_misc]
  ]

  # return an array of status/value pairs for passing to select()
  def self.status_select
    @@statuses
  end

  # Write the virtual attribute tag_tokens (a list of ids) to
  # update the real attribute tag_ids
  def tag_tokens=(ids)
    # The list may contain new terms, passed in single quotes
    self.tags = ids.split(",").map { |e| 
      if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags
        Tag.find e.to_i
      else
        e.sub!(/^\'(.*)\'$/, '\1') # Strip out enclosing quotes
        Tag.strmatch(e, userid: self.current_user, assert: true)[0]
      end
    }.compact.uniq
  end

  public
  
# Methods for data associated with a given user: comment, status, privacy, etc.

  # Return the number of times a recipe's been marked
  def num_cookmarks
     Rcpref.where(["recipe_id = ? AND in_collection = ?", self.id, true]).count
  end

  # Is the recipe cookmarked by the given user?
  def marked? uid=nil
    (ref = (uid.nil? ? current_ref : ref_for(uid, false))) && ref.in_collection
  end

  # Set the mod time of the recipe to now (so it sorts properly in Recent lists)
  # If a uid is provided, touch the associated rcpref instead
  def touch uid, add_to_collection = true
    rcpref = ref_for uid, true
    if add_to_collection && !rcpref.in_collection
      rcpref.in_collection = true
      rcpref.save
    else
      rcpref.touch
    end
    rcpref
  end
  
  # Set the updated_at field for the rcpref for this user and this recipe
  def uptouch(uid, time)
    ref = ref_for uid, true
    if time > ref.updated_at
      Rcpref.record_timestamps=false
      ref.updated_at = time 
      ref.save
      Rcpref.record_timestamps=true
    else
      false
    end
  end
  
  # Present the time-since-touched in a text format
  def touch_date uid=nil
    (ref = uid.nil? ? current_ref : ref_for(uid, false)) && ref.updated_at
  end
  
  # Present the time since collection in a text format
  def collection_date uid=nil
    debugger
    (ref = uid.nil? ? current_ref : ref_for(uid, false)) && ref.created_at
  end
  
  # The comment for a recipe comes from its rcprefs for a 
  # given user_id 
  # Get THIS USER's comment on a recipe
  def comment
    current_ref.comment || ""
  end

  # Get another user's comment on a recipe
  def comment_of_user(uid)
    ((ref = ref_for(uid,false)) && ref.comment) || ""
  end

  # Record THIS USER's comment in the reciperefs join table
  def comment=(str)
    current_ref.comment = str
  end

  # Casual setting of privacy for the recipe: immediate save for 
  # this recipe/user combo.
  def private=(val)
     current_ref.private = (val != "0")
  end

  def private
    current_ref.private
  end

  # Casual setting of status for the recipe: immediate save for 
  # this recipe/user combo.
  # Presented as an integer related to @@statuses
  def status=(val)
     current_ref.status = val.to_i
  end

  def status
    current_ref.status
  end
  
  def remove_from_collection uid
    if (rcpref = ref_for uid, false) && rcpref.in_collection
      rcpref.in_collection = false
      rcpref.save
    end
  end

# Currently unused functionality for parsing and annotation
@@DoSpans

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

protected

  # Get the cached rcpref for the recipe and its current user.
  # 'uid' may be set to assert a new current user
  def current_ref uid=nil, force=true
    @current_ref = ref_for(@current_user = (uid || @current_user), force)
  end

  # Return the reference for the given user and this recipe, creating a new one as necessary
  # If 'force' is set, and there is no reference to the recipe for the user, create one
  def ref_for uid, force=true
    if uid.nil? # No user => no ref
      force && Rcpref.new(comment: "")  
    elsif @current_ref && @current_ref.user_id && @current_ref.user_id == uid # Consult the cache
      @current_ref
    elsif force
      if !users.exists? uid 
        # Create a new rcpref between the user and the recipe
        users << User.find(uid)
      end
      self.rcprefs.where("user_id = ?", uid)[0]
    else
      nil
    end
  end
  
end

require './lib/Domain.rb'
require './lib/RPDOM.rb'
require './lib/uri_utils.rb'
require 'open-uri'
require 'nokogiri'
require 'htmlentities'

class GettableURLValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if(attribute == :url) && record.url_changed?
      if test_result = test_link(value) # by_link(value)
        # If the URL has relocated, we'll smartly adjust our link--UNLESS we're duplicating another URL
        if test_result.kind_of?(String)
          record.url = test_result if Recipe.where(url: test_result).empty?
        end
      else
        record.errors.add :url, "\'#{value}\' doesn't seem to be a valid URL (can you use it as an address in your browser?)"
        return nil
      end
    elsif attribute == :picurl
      unless record.picurl && (record.picurl =~ /^data:/) # Use a data URL directly w/o taking a thumbnail
        if record.url_changed? || record.picurl_changed? || !record.thumbnail
          Delayed::Job.enqueue record
          # record.thumbnail= Thumbnail.acquire( record.url, record.picurl ) 
          # if record.thumburl.bad_url?
            # record.errors.add :picurl, "\'#{value}\' doesn't point to a picture"
            # return nil
          # end
        end
      end
    end
    true
  end
end

class Recipe < ActiveRecord::Base
  include Taggable
  attr_accessible :title, :url, :alias, :ratings_attributes, :comment, :status, :private, :picurl, :tagpane, :href
  after_save :save_ref

  validates :title, :presence=>true 
#  validates :url,  :presence=>true, :gettableURL => true
#  validates :picurl, :gettableURL => true
# private

  # Before saving the recipe, take the chance to generate a thumbnail (in background)
  before_save :generate_thumbnail

private
  def generate_thumbnail 
    unless picurl && (picurl =~ /^data:/) # Use a data URL directly w/o taking a thumbnail
      if url_changed? || picurl_changed? || !thumbnail
        self.thumbnail = nil
        Delayed::Job.enqueue self
      end
    end
  end
public
  # XXX Defunct as soon as tagging data gets moved to Taggings
  has_many :tagrefs, :dependent=>:destroy
  has_many :x_tags, :through=>:tagrefs, :autosave=>true, :class_name => "Tag", :source => :tag, :foreign_key => :tag_id
  
  belongs_to :thumbnail, :autosave => true, :dependent => :destroy
  
  has_many :ratings, :dependent=>:destroy
  has_many :scales, :through=>:ratings, :autosave=>true
  # attr_reader :ratings_attributes
  accepts_nested_attributes_for :ratings, :reject_if => lambda { |a| a[:scale_val].nil? }, :allow_destroy=>true

  validates_uniqueness_of :url
  
  has_one :link, :as => :entity

  has_many :rcprefs, :dependent=>:destroy
  has_many :users, :through=>:rcprefs, :autosave=>true
  attr_reader :comment
  attr_accessor :private
  attr_reader :status
  
  @@coder = HTMLEntities.new

  def refresh
    Delayed::Job.enqueue self
  end 
  
  def perform
    puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> Validating picurl with url '#{url}' and picurl '#{picurl}'"
    unless thumbnail
      self.thumbnail= Thumbnail.acquire( url, picurl )
      save
    end
  end
  
  def site
    @site ||= Site.by_link(url) || (href && Site.by_link(href))
  end
    
  # Either fetch an exising recipe record or make a new one, based on the
  # params. If the params have an :id, we find on that, otherwise we look
  # for a record matching the :url. If there are no params, just return a new recipe
  # If a new recipe record needs to be created, we also do QA on the provided URL
  # and dig around for a title.
  # Either way, we also make sure that the recipe is associated with the given user
  def self.ensure( userid, params, add_to_collection = true, extractions = nil)
    if extractions ||= SiteServices.extract_from_page(params[:url], :label => [:URI, :Image, :Title])
      # Extractions are parameters derived directly from the page
      if extractions[:URI]
        params[:url] = extractions[:URI] 
      elsif extractions[:href]
        params[:url] = extractions[:href] 
      end
      params[:picurl] = extractions[:Image] if extractions[:Image]
      params[:title] = extractions[:Title] if extractions[:Title]
      params[:href] = extractions[:href] if extractions[:href]
    end
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
      params.delete(:rcpref)
      rcp = Recipe.new params
      if rcp.url.blank?  # Check for non-empty URL
        rcp.errors.add :url, "can't be blank"
      elsif rcp.url.match %r{^http://#{current_domain}} # Check we're not trying to link to a RecipePower page
        rcp.errors.add :base, "Sorry, can't cookmark pages from RecipePower. (Does that even make sense?)"
      # Find the site for this url
      elsif !rcp.site # ...if site can be found/created under this URL (or href)
        rcp.errors.add :url, "doesn't make sense or can't be found"
      elsif saved = Recipe.where(url: (rcp.url = rcp.site.make_link_absolute(rcp.url))).first
        # Recipe already exists under this url
        rcp = saved
      else
        rcp.picurl = rcp.site.make_link_absolute rcp.picurl if rcp.picurl
        rcp.title = rcp.site.trim_title rcp.title # = ((site.yield :Title, url)[:Title] || rcp.title).html_safe unless rcp.title
        rcp.save
      end
    end
    # If all is well, make sure it's on the user's list
    if userid && rcp.id && rcp.errors.empty?
      rcp.current_user = userid # Default for subsequent operations
      rcp.touch add_to_collection
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
      self.title = (st.yield :Title, st.sampleURL)[:Title] || ""
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

  @@statuses = [
    [:recipe_status_high, MyConstants::Rcpstatus_rotation], 
    [:recipe_status_medium, MyConstants::Rcpstatus_favorites],
    [:recipe_status_low, MyConstants::Rcpstatus_interesting],
    [:recipe_status_default, MyConstants::Rcpstatus_misc]
  ]

  # return an array of status/value pairs for passing to select()
  def self.status_select
    @@statuses
  end
  public
  
# Methods for data associated with a given user: comment, status, privacy, etc.

  # An after_save method for a recipe which saves the 
  # recipe/user info cache for the current user
  def save_ref
    if ref = ref_for(nil, false) # Use current user, don't create ref
      ref.save 
    end
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

  # Return the number of times a recipe's been marked
  def num_cookmarks
     Rcpref.where(["recipe_id = ? AND in_collection = ?", self.id, true]).count
  end

  # Is the recipe cookmarked by the given user (or current_user if none given)?
  def cookmarked uid=nil
    if(ref = ref_for uid, false )
      ref.in_collection
    end
    # (ref = (uid.nil? ? current_ref : ref_for(uid, false))) && ref.in_collection
  end
  
  def remove_from_collection uid=nil
    if (ref = ref_for(uid, false)) and ref.in_collection
      ref.in_collection = false
      ref.save
    end
  end 

  # Set the mod time of the recipe to now (so it sorts properly in Recent lists)
  # If a uid is provided, touch the associated rcpref instead
  def touch add_to_collection = true
    # Fetch the reference for this user, creating it if necessary
    ref = ref_for(@current_user, true) # Make if necessary
    if do_save = (add_to_collection && !ref.in_collection) # Collecting for the first time
      ref.in_collection = true
      do_stamp = ref.created_at && ((Time.now - ref.created_at) > 5) # It's been saved before => update created_at time
    end
    do_save = true if ref.created_at.nil?
    if ref.user_id # No point saving w/o a user id (recipe id is assumed)
      if do_stamp
        ref.created_at = ref.updated_at = Time.now
        Rcpref.record_timestamps=false
        ref.save
        Rcpref.record_timestamps=true
      elsif do_save # Save, whether previously saved or not
        ref.save
      else
        ref.touch
      end
    end
    "Created: #{ref.created_at}.........Updated: #{ref.updated_at}"
  end
  
  # Present the time-since-touched in a text format
  def touch_date uid=nil
    if (ref = ref_for uid, false)
      ref.updated_at
    end
    #(ref = uid.nil? ? current_ref : ref_for(uid, false)) && ref.updated_at
  end
  
  # Present the time since collection in a text format
  def collection_date uid=nil
    if (ref = ref_for uid, false) && ref.in_collection
      ref.created_at
    end
    # (ref = uid.nil? ? ref_for : ref_for(uid, false)) && ref.created_at
  end
  
  # The comment for a recipe comes from its rcprefs for a given user_id 
  # Get THIS USER's comment on a recipe
  def comment uid=nil
    ((ref = ref_for uid, false) && ref.comment) || ""
  end

  # Record THIS USER's comment in the reciperefs join table
  def comment=(str)
    ref_for(@current_user, true).comment = str
  end

  def private uid=nil
    if (ref = ref_for(uid, false))
      ref.private
    end
  end

  # Casual setting of privacy for the recipe's current user.
  def private=(val)
    ref_for(@current_user, true).private = (val != "0")
  end

  def status uid=nil
    (ref = ref_for uid, false ) ? ref.status : MyConstants::Rcpstatus_misc
  end

  # Presented as an integer related to @@statuses
  def status=(val)
     ref_for(@current_user, true).status = val.to_i
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

  # Return the reference for the given user and this recipe, creating a new one as necessary
  # If 'force' is set, and there is no reference to the recipe for the user, create one
  def ref_for uid, force=true
    uid = (uid or @current_user)
    ref = 
    if uid.nil? # No user => no ref
      force && Rcpref.new(comment: "")  
    elsif @current_ref && @current_ref.user_id && (@current_ref.user_id == uid) # Consult the cache
      @current_ref
    else
      if !users.exists?(uid) && force
        # Create a new rcpref between the user and the recipe
        users << User.find(uid)
      end
      self.rcprefs.where("user_id = ?", uid)[0]
    end
    @current_ref = ref if uid == @current_user
    ref
  end
public

end

require './lib/Domain.rb'
require './lib/RPDOM.rb'
require './lib/my_constants.rb'
require './lib/html_utils.rb'
require 'open-uri'
require 'nokogiri'
require 'htmlentities'
require 'htmlbeautifier'
require 'site_services.rb'

class Recipe < ApplicationRecord
  include Taggable # Can be tagged using the Tagging model
  include Collectible
  include Referrable # Is associated with a Referent
  include Backgroundable
  backgroundable
  include Pagerefable # Has a PageRef linking to and reporting on the content
  pagerefable :url
  # The picurl attribute is handled by the :picture reference of type ImageReference
  picable :picurl, :picture
  include Trackable
  attr_trackable :picurl, :title, :description, :content

  delegate :recipe_page, :to => :page_ref

  before_save do |recipe|
    # Arm the recipe for launching
    if recipe.anchor_path_changed? ||
        recipe.focus_path_changed? ||
        (recipe.content.blank? && recipe.anchor_path.present? && recipe.focus_path.present?)
      recipe.content = nil
      recipe.status = "virgin"
    end
    if recipe.content_changed?
      # Set tags according to annotations
      RecipeServices.new(self).inventory do |rpclass, node|
        # #inventory will call a block on found nodes, once for each token
        case rpclass
        when :rp_title
          accept_attribute :title, node.text
        when :rp_ingline
          x=2
        end
      end
    end
  end

  # This is kind of smelly, but, given that 1) there is no association that maps between one RecipePage
  # and many Recipes through a single PageRef, and 2) a recipe doesn't necessarily have either a PageRef
  # or a RecipePage, this is the only way to do it
  # after_save { |recipe| recipe.page_ref&.recipe_page&.save if recipe.page_ref&.recipe_page&.changed? }

  # attr_accessible :title, :ratings_attributes, :description, :url,
                  # :prep_time, :prep_time_low, :prep_time_high,
                  # :cook_time, :cook_time_low, :cook_time_high,
                  # :total_time, :total_time_low, :total_time_high,
                  # :yield, :page_ref_attributes

  # For reassigning the kind of the page_ref and/or modifying site's parsing info
  accepts_nested_attributes_for :page_ref
  has_one :site, :through => :page_ref
  accepts_nested_attributes_for :site
  #, :comment, :private, :tagpane, :status, :alias, :picurl :href, :collection_tokens

  validates :title, length: { minimum: 2 }
  # private

  # has_many :ratings, :dependent => :destroy
  # has_many :scales, :through => :ratings, :autosave => true
  # attr_reader :ratings_attributes
  # accepts_nested_attributes_for :ratings, :reject_if => lambda { |a| a[:scale_val].nil? }, :allow_destroy => true

  @@coder = HTMLEntities.new

  # Return scopes for searching the title and description
  # The block, if given, is for the caller to assert its own scope, joining it with this scope
  def self.strscopes matcher
    scope = block_given? ? yield() : self.unscoped
    [
        scope.where('"recipes"."title" ILIKE ? or "recipes"."description" ILIKE ?', matcher, matcher)
    ] + PageRef.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:page_ref => inward} : :page_ref
      block_given? ? yield(joinspec) : self.joins(joinspec)
    }
  end

  def self.mass_assignable_attributes
    super + [ :title, :description, :content, :anchor_path, :focus_path, { :page_ref_attributes => (PageRef.mass_assignable_attributes << :id ) }, {:gleaning_attributes => %w{ Title Description }}]
  end

  # These HTTP response codes lead us to conclude that the URL is not valid
  @@BadResponseCodes = [400, 404, 410]

  # -> true, false, nil
  # Report on the reachability of a Gleanable.
  # return true if EITHER the pageref or the gleaning succeed (definitely reachable)
  # return false if one of them got a 404 error (definitely not reachable)
  # return nil if inconclusive (maybe an authorization error, whatever)
  def reachable?
    return true if (page_ref && (page_ref.good? || (page_ref.http_status == 200))) || (gleaning && gleaning.good?)
    return false if (page_ref && @@BadResponseCodes.include?(page_ref.http_status)) &&
        (gleaning && @@BadResponseCodes.include?(gleaning.http_status))
  end

  # Write the title attribute only after trimming and resolving HTML entities
  def title= ttl
    ttl = site_service.trim_title(ttl) if site_service
    write_attribute :title, @@coder.decode(ttl)
  end

  # Writing the picture URL redirects to acquiring an image reference
  def picurl= pu
    self.picture = ImageReferenceServices.find_or_initialize site_service&.resolve(pu)
  end

  # Memoized SiteServices
  def site_service
    @ss ||= site && SiteServices.new(site)
  end

  # Absorb another recipe
  def absorb other, destroy=true
    self.description = other.description if description.blank?
    # Move feed_entries from the old recipe to the new
    FeedEntry.where(:recipe_id => other.id).each { |fe|
      fe.recipe = self
      fe.save
    }
    super other if defined?(super)
    other.reload
    other.destroy if destroy
    save
  end

  ##### Trackable matters #########k
  # Request attributes from page_ref as necessary
  def request_dependencies 
    # If we haven't persisted, then the page_ref has no connection back
    page_ref.recipes << self unless persisted? || page_ref.recipes.to_a.find { |r| r == self }
    page_ref.request_attributes *(needed_attributes & [ :picurl, :title, :description ]) # Those to be got from PageRef
  end

  # Override to acccept values from page_ref
  def adopt_dependencies
    super if defined? super
    # Get the available attributes from the PageRef
    # Translate what the PageRef is offering into our attributes
    accept_attribute :picurl, page_ref.picurl if page_ref.picurl_ready?
    accept_attribute :title, page_ref.title if page_ref.title_ready?
    accept_attribute :description, page_ref.description if page_ref.description_ready?
  end

  ##### Backgroundable matters #########

  # Pagerefable manages getting the PageRef to perform and reporting any errors
  def perform
    page_ref.ensure_attributes :content
    # The recipe_page will assert path markers and clear our content
    # if changes during page parsing were significant
    if content_needed?
      if page_ref.recipe_page_ready?  # Ready to build
        # reload if persisted? # Possibly the recipe_page changed us
        recipe_page.ensure_attributes :content # Parse the page into one or more recipes
      end
      content_to_parse =
        (recipe_page&.selected_content(anchor_path, focus_path) if anchor_path.present? && focus_path.present?) ||
        page_ref.trimmed_content
      return unless content_to_parse.present?
      ps = ParserServices.parse entity: self, content: content_to_parse
      new_content = ps.annotate
      nc1 = ParsingServices.new(self).parse_and_annotate content_to_parse
      return unless new_content.present? # Parsing was a success
      accept_attribute :content, new_content, true  # Force the new content
    end
    # super if defined?(super)
  end

end

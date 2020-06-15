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

  delegate :recipe_page, :to => :page_ref

  before_save do |recipe|
    # Arm the recipe for launching
    if recipe.anchor_path_changed? ||
        recipe.focus_path_changed? ||
        (recipe.content.blank? && recipe.anchor_path.present? && recipe.focus_path.present?)
      recipe.content = nil
      recipe.status = "virgin"
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

  # For reassigning the kind of the page_ref
  accepts_nested_attributes_for :page_ref
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
    super + [ :title, :description, :content, :anchor_path, :focus_path, {:gleaning_attributes => %w{ Title Description }}]
  end

  # Content to parse: either the recipe_page's content, or the
  def content_to_parse
    return nil unless page_ref
    page_ref.recipe_page&.selected_content(anchor_path, focus_path) || page_ref.trimmed_content
  end

  # The presented content for a recipe defers to the page ref if we haven't parsed the recipe yet
  def presented_content
    content.if_present ||
        page_ref&.recipe_page&.selected_content(anchor_path, focus_path) || # Presumably this is pre-trimmed
        page_ref&.massaged_content
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
    ttl = site_service.trim_title(ttl) if site
    write_attribute :title, @@coder.decode(ttl)
  end

  # Writing the picture URL redirects to acquiring an image reference
  def picurl= pu
    pu = site_service.resolve(pu) if site_service
    self.picture = ImageReference.find_or_initialize pu
  end

  def site_service
    @ss ||= (SiteServices.new(ensure_site) if ensure_site)
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

  def bkg_launch force=false
    # If we haven't persisted, then the page_ref has no connection back
    page_ref.recipes << self unless persisted? || page_ref.recipes.to_a.find { |r| r == self }
    # Possible prerequisites for a recipe launch:
    if !content.present? && site&.finder_for('Content')
      # Need to launch the recipe_page to collect content
      page_ref.build_recipe_page if !recipe_page
      recipe_page.bkg_launch
      force = true
    end
    if title.blank? || picurl.blank? || description.blank?
      page_ref&.bkg_launch
      force = true  if page_ref.virgin?
    end
    super(force) if defined?(super)
  end

  def perform
    if false # site&.finder_for 'Content'
      page_ref.bkg_land
      page_ref.create_recipe_page if !recipe_page
      recipe_page.bkg_land # The recipe_page will assert path markers and clear the content as nec.
      # recipe_page.save if persisted? && recipe_page.changed?
      if content.blank?
        reload if persisted?
        self.content = ParsingServices.new(self).parse_and_annotate(content_to_parse).if_present || presented_content
        RecipeServices.new(self).inventory # Set tags according to annotations
      end
    end
    super if defined?(super)
  end

  def after
    # After the job runs, this is our chance to set status
    self.status = if site&.finder_for('Content')
                    content.present? ? :good : :bad
                  else
                    page_ref&.status || :good
                  end
    super
  end

  # This is called when the page_ref finishes updating
  def adopt_page_ref
    self.title = page_ref.title if page_ref.title.present? && title.blank?
    self.picurl = page_ref.picurl if page_ref.picurl.present? && picurl.blank?
    self.description = page_ref.description if page_ref.description.present? && description.blank?
    title.present?
  end

end

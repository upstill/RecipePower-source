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
  attr_trackable :picurl, :title, :description,
                 :content, :ingredients, :instructions,
                 :prep_time, :cook_time, :total_time, :yields, :serves

  delegate :recipe_page, :to => :page_ref

=begin
  after_initialize do |rcp|
    # The actual launch will occur after_save
    request_attributes [ :title, :picurl, :content ] unless persisted?
  end
=end

  # TODO: move time-consuming attributes into secondary_attributes
  def standard_attributes
    [ :title, :picurl, :content, :ingredients, :instructions, :prep_time, :cook_time, :total_time, :yields, :serves ]
  end

  def secondary_attributes
    [] # [ :ingredients, :instructions, :prep_time, :cook_time, :total_time, :yield ]
  end

  before_save do |recipe|
    # Arm the recipe for launching
    if !@being_saved && (recipe.anchor_path_changed? ||
        recipe.focus_path_changed? ||
        (recipe.content.blank? &&
            recipe.anchor_path.present? &&
            recipe.focus_path.present?
        ))
      @being_saved = true
      recipe.refresh_attributes [ :content ]
      @being_saved = false
    end
  end

  # For reassigning the kind of the page_ref and/or modifying site's parsing info
  accepts_nested_attributes_for :page_ref
  has_one :site, :through => :page_ref
  accepts_nested_attributes_for :site

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
  alias_method :o_title_eq, :'title='
  def title= ttl
    ttl = site_service.trim_title(ttl) if site_service
    logger.debug "Recipe writing title"
    o_title_eq(ttl) # write_attribute :title, @@coder.decode(ttl)
  end

  # Writing the picture URL redirects to acquiring an image reference
  def picurl= pu
    self.picture = ImageReferenceServices.find_or_initialize (site_service ? site_service.resolve(pu) : pu)
  end

  # Memoized SiteServices
  def site_service
    @ss ||= site && SiteServices.new(site)
  end

  # Absorb another recipe
  def absorb( other, destroy: true)
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

  ##### Trackable matters #########

  def attributes_due_from_page_ref minimal_attribs=needed_attributes
    needed_now = minimal_attribs & needed_attributes
    # We ask PageRef to provide its recipe_page if possible
    # needed_now << :recipe_page if needed_now.include?(:content)
    PageRef.tracked_attributes & [ :content, :picurl, :title, :description, :recipe_page ] & needed_now
  end

  # Request attributes from page_ref as necessary, after record is saved.
  # Return: boolean indicating need to start background processing
  def drive_dependencies minimal_attribs=needed_attributes, overwrite: false, restart: false
    super || content_needed?
  end

  # Override to acccept values from page_ref, optionally forcing it to completion
  def adopt_dependencies synchronous: false, final: false
    super if defined? super # Force the page_ref to complete its background work
    # Translate what the PageRef is offering into our attributes
    if page_ref&.complete?
      adopt_dependency :picurl, page_ref
      adopt_dependency :title, page_ref
      adopt_dependency :description, page_ref
      errors.add :url, "not valid in page_ref: #{page_ref.error_message}" if page_ref.http_status != 200
    end
  end

  ##### Backgroundable matters #########

  # Pagerefable manages getting the PageRef to perform and reporting any errors
  def perform
    def attribute_as_token attrname
      (attrname == :ingredients) ? :rp_inglist : :"rp_#{attrname}" if attrname != :content
    end
    def token_as_attribute token
      (token == :rp_inglist) ? :ingredients : :"#{token.to_s.sub('rp_', '')}"
    end
    def attribute_as_type attrname
      case attrname
      when :content
      when :ingredients
      when :instructions
      when :prep_time, :cook_time, :total_time
        :timerange
      when :yields
        :amountstring
      when :serves
        :numrange
      end
    end
    # If the page_ref isn't ready, go back in the queue
    super if defined?(super) # await page_ref as required
    # The recipe_page will assert path markers and clear our content
    # if changes during page parsing were significant
    need_now = needed_attributes & [ :content, :ingredients, :instructions, :prep_time, :cook_time, :total_time, :yields, :serves ]
    if need_now.present?
      # If there's an associated RecipePage, then we'll be depending on its content
      await recipe_page if page_ref.recipe_page_ready?
      content_to_parse =
        (recipe_page&.selected_content(anchor_path, focus_path) if anchor_path.present? && focus_path.present?) ||
        page_ref.trimmed_content
      if content_to_parse.present? # Can't proceed w/o something to parse!
        # Translate the recipe attributes into grammar tokens
        as_tokens = need_now.collect { |attrname| attribute_as_token attrname }.compact
        ps = ParserServices.new entity: self, input: content_to_parse, grammar_mods: site.grammar_mods
        if ps.go seeking: as_tokens, annotate: true # No point proceeding if the parse fails
          # Ideally, all content will have been parsed out and can now be assigned to attributes
          self.content = ps.content if content_needed?
          need_now.each do |attrname|
            # Pull each needed attribute value according to token and type
            token = attribute_as_token attrname
            next unless (type = attribute_as_type attrname) &&
                (tr = ps.found_for(token, as: type).first)
            self.send :"#{attrname}=", tr
          end
          # If a Yield appeared as a number of servings, transfer it to the :serves attribute
          if yields&.match /(.*) servings?/i
            num_or_range = $1
            num_or_range.match /(\d*)-?(\d*)?$/
            min = $1.to_i ; max = ($2.present? ? $2.to_i : min)
            self.serves = min..max
            self.yields = ''
          end
          # Assert extracted title
          if found = ps.nkdoc.css('.rp_title').first
            self.title = found.text
          end
          # Assert extracted ingredient tags
          TaggingServices.new(self).set_tags User.inventory_user_id,
                                             :Ingredient => ps.nkdoc.css('.rp_ingredient_tag').collect { |node| node['value'].if_present || node.text }
        end
      end
      # Clear all immediately-needed attributes, whether parsed out or not, until notified otherwise
      need_now.each { |attrname| attrib_needed! attrname, false }
    end
  end

end

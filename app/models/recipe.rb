require './lib/Domain.rb'
require './lib/RPDOM.rb'
require './lib/my_constants.rb'
require 'open-uri'
require 'nokogiri'
require 'htmlentities'

class Recipe < ActiveRecord::Base
  include Collectible
  include Referrable
  # The url attribute is handled by a reference of type RecipeReference
  linkable :url, :reference
  # The picurl attribute is handled by the :picture reference of type ImageReference
  picable :picurl, :picture

  attr_accessible :title, :ratings_attributes, :description, :url #, :comment, :private, :tagpane, :status, :alias, :picurl :href, :collection_tokens

  validates :title, length: { minimum: 2 }
  # private

  # has_many :ratings, :dependent => :destroy
  # has_many :scales, :through => :ratings, :autosave => true
  # attr_reader :ratings_attributes
  # accepts_nested_attributes_for :ratings, :reject_if => lambda { |a| a[:scale_val].nil? }, :allow_destroy => true

  @@coder = HTMLEntities.new

  # Return scopes for searching the title and description
  def self.strscopes matcher
    scope = block_given? ? yield() : self.unscoped
    [
        scope.where('"recipes"."title" ILIKE ?', matcher),
        scope.where('"recipes"."description" ILIKE ?', matcher)
    ] + Reference.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:reference => inward} : :reference
      block_given? ? yield(joinspec) : self.joins(joinspec)
    }
  end

  # Write the title attribute only after trimming and resolving HTML entities
  def title= ttl
    ttl = site_service.trim_title(ttl) if site
    write_attribute :title, @@coder.decode(ttl)
  end

  # Writing the picture URL redirects to acquiring an image reference
  def picurl= pu
    pu = site_service.resolve(pu) if site
    self.picture = ImageReference.find_or_initialize(pu).first
  end

  def site_service
    @ss ||= SiteServices.new site
  end

  # Either fetch an existing recipe record or make a new one, based on the
  # params. If the params have an :id, we find on that, otherwise we look
  # for a record matching the :url. If there are no params, just return a new recipe
  # If a new recipe record needs to be created, we also do QA on the provided URL
  # and dig around for a title, description, etc.
  # Either way, we also make sure that the recipe is associated with the given user
  def self.ensure params, extractions = nil
    if params[:id]
      # Recipe exists and we're just touching it for the user
      rcp = Recipe.find params[:id]
    elsif !(rcp = RecipeReference.lookup_recipe params[:url])
      if !extractions
        # extractions = SiteServices.extract_from_page(params[:url])
        extractions = FinderServices.findings params[:url]
        if extractions.empty?
          rcp = self.new params
          rcp.errors[:url] = 'Doesn\'t appear to be a working URL: we can\'t open it for analysis'
          return rcp
        end
      end
      # Extractions are parameters derived directly from the page
      logger.debug "Extracted from #{params[:url]}:"
      extractions.each { |key, value| logger.debug "\t#{key}: #{value}" }
      params = {
          :description => extractions[:Description],
          :url => (extractions[:URI] || extractions[:href]),
          :picurl => extractions[:Image],
          :title => extractions[:Title]
      }.compact
      if params.blank?
        rcp = self.new
      elsif (id = params[:id].to_i) && (id > 0) # id of 0 means create a new recipe
        begin
          rcp = Recipe.find id
        rescue => e
          rcp = self.new
          rcp.errors.add :id, "There is no recipe number #{id.to_s}"
        end
      elsif !(rcp = RecipeReference.lookup_recipe params[:url]) # Try again to find based on the extracted url
        # No id: create based on url
        params.delete(:rcpref)
        # Assigning title and picurl must wait until the url (and hence the reference) is set
        rcp = Recipe.new params.slice! :title, :picurl
        rcp.update_attributes params # Now set the title
        if rcp.url.match %r{^#{rp_url}} # Check we're not trying to link to a RecipePower page
          rcp.errors.add :base, "Sorry, can't cookmark pages from RecipePower. (Does that even make sense?)"
        else
          RecipeServices.new(rcp).robotags = extractions  # Set tags, etc., derived from page
        end
      end
    end
    rcp
  end

  # Absorb another recipe
  def absorb other, destroy=true
    self.description = other.description if description.blank?
    # Move feed_entries from the old recipe to the new
    FeedEntry.where(:recipe_id => other.id).each { |fe|
      fe.recipe = self
      fe.save
    }
    super other if defined? super
    other.reload
    other.destroy if destroy
    save
  end

end

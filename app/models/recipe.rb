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

  attr_accessible :title, :ratings_attributes, :description, :url #, :comment, :private, :tagpane, :status, :alias, :picurl :href, :collection_tokens, :channel_tokens

  validates :title, length: { minimum: 2 }
  # private

  # has_many :ratings, :dependent => :destroy
  # has_many :scales, :through => :ratings, :autosave => true
  # attr_reader :ratings_attributes
  # accepts_nested_attributes_for :ratings, :reject_if => lambda { |a| a[:scale_val].nil? }, :allow_destroy => true

  @@coder = HTMLEntities.new

  # Return scopes for searching the title and description
  def self.strscopes scope, str_to_match
    [
        scope.where('recipes.title ILIKE ?', "%#{str_to_match}%"),
        scope.where('recipes.description ILIKE ?', "%#{str_to_match}%")
    ]
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
        extractions = SiteServices.extract_from_page(params[:url])
        if extractions.empty?
          rcp = self.new params
          rcp.errors[:url] = "Doesn't appear to be a working URL: we can't open it for analysis"
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
      else
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
    # This recipe may be presenting a URL that redirects to the target => include that URL in the table
    # RecipeReference.find_or_initialize other.url, affiliate: self
    # Apply thumbnail and comment, if any
    other.references.each { |other_ref|
      other_ref.recipe = self
      other_ref.save
    }
    unless other.picurl.blank? || !picurl.blank?
      self.picurl = other.picurl
    end
    self.description = other.description if description.blank?
    unless other.rcprefs.empty?
      xfers = []
      other.rcprefs.each { |my_ref|
        # Redirect each rcpref to the other, merging them when there's already one for a user
        # comment, private, status, in_collection, edit_count
        if other_ref = self.rcprefs.where(user_id: my_ref.user_id).first
          # Transfer reference information
          other_ref.private ||= my_ref.private
          other_ref.comment = my_ref.comment if other_ref.comment.blank?
          other_ref.in_collection ||= my_ref.in_collection
          other_ref.edit_count += my_ref.edit_count
          other_ref.save
        else
          # Simply redirect the ref, thus moving the owner from the old recipe to the new
          # (Need to do this after iterating over the recipe's refs)
          xfers << my_ref.clone
        end
      }
      unless xfers.empty?
        self.rcprefs = self.rcprefs + xfers
      end
    end
    # Move feed_entries from the old recipe to the new
    FeedEntry.where(:recipe_id => other.id).each { |fe|
      fe.recipe = self
      fe.save
    }
    other.reload
    other.destroy if destroy
    save
  end

end

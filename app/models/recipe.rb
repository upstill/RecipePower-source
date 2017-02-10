require './lib/Domain.rb'
require './lib/RPDOM.rb'
require './lib/my_constants.rb'
require 'open-uri'
require 'nokogiri'
require 'htmlentities'

class Recipe < ActiveRecord::Base
  include Collectible
  # TODO: pull the switch by making recipes pagerefable rather than linkable
  # The url attribute is handled by a reference of type RecipeReference
  include Referrable
  # linkable :url, :reference, gleanable: true
  include Pagerefable
  pagerefable :url, gleanable: true # belongs_to :page_ref #
  # The picurl attribute is handled by the :picture reference of type ImageReference
  picable :picurl, :picture

  attr_accessible :title, :ratings_attributes, :description, :url,
                  :prep_time, :prep_time_low, :prep_time_high,
                  :cook_time, :cook_time_low, :cook_time_high,
                  :total_time, :total_time_low, :total_time_high,
                  :yield

  belongs_to :page_ref
  #, :comment, :private, :tagpane, :status, :alias, :picurl :href, :collection_tokens

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
    self.picture = ImageReference.find_or_initialize(pu).first
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
    super other if defined? super
    other.reload
    other.destroy if destroy
    save
  end

end

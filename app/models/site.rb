# encoding: UTF-8
require './lib/uri_utils.rb'

class Site < ActiveRecord::Base
  include Taggable

  include Linkable # Required by Picable
  linkable :home, :reference

  include Picable
  picable :logo, :thumbnail

  # site: root of the domain (i.e., protocol + domain); suitable for pattern-matching on a reference URL to glean a set of matching Sites
  # subsite: a path relative to the domain which differentiates among Sites with the same domain (site attribute)
  # home: where the nominal site lives. This MAY be (site+subsite), but in cases of indirection, it may be an entirely
  #      different domain. (See Splendid Table on publicradio.org redirect to splendidtable.org)
  # So, (site+sample) and (site+subsite) should be valid links, but not necessarily (home+sample), since redirection
  #      may alter the path
  # Also, in most cases, site==home (when the domain is home, i.e. subsite is empty); in others, (site+subsite)==home,
  #     and only rarely will home be different from either of those
  attr_accessible :finders_attributes, :sample, :oldname, :ttlcut, :finders, :reviewed, :description, :reference, :references # , :subsite, :home, :logo, :oldsite, :scheme, :host, :port

  belongs_to :referent # See before_destroy method, :dependent=>:destroy

  has_many :finders, :dependent=>:destroy
  accepts_nested_attributes_for :finders, :allow_destroy => true
  
  has_many :feeds, :dependent=>:destroy

  # When creating a site, also create a corresponding site referent
  # before_create :ensure_referent
  
  after_initialize :post_init
  
  def perform
    feeds.each { |feed| feed.destroy if (feed.user_ids-[4]).empty? }
  end

protected

  # If this is the last site associated with its referent, destroy the referent
  before_destroy do |site|
    sibling_sites = Site.where(referent_id: site.referent_id)
    site.referent.destroy if (sibling_sites.count == 1) && (sibling_sites.first.id == site.id)
  end

  # When a site is first created, it needs to have a SiteReference built from its sample attribute
  def post_init
    unless id
      self.sample = normalize_url sample
      # Attach relevant references if they haven't been mass-assigned
      self.home = sample if self.references.empty?
      # Give the site a provisional name, the host name minus 'www.', if any
      self.name = domain.sub(/www\./, '') if domain # Creates a corresponding referent
    end
  end

public

  # Produce a Site for a given url whether or not one already exists
  def self.lookup link
    refs = SiteReference.find_or_initialize_canonical link
    if refs && refs.first
      refs.first.site || self.create(sample: link, references: refs, reference: refs.first)
    end
  end

  def domain
    host_url home # scheme+"://"+host+((port=="80") ? "" : (":"+port))
  end

=begin
  def oldsite
    reference.url
  end

  def sampleURL
    sample ? URI.join( sample, reference.url ).to_s : ""
  end

  # By default the site's home page is (site+subsite), but that may be overridden (due to indirection) by
  # setting the home attribute
  def home_page
    reference.url # home.blank? ? "#{site}#{subsite}" : home
  end
=end

  def name
    referent.name
  end

  def name=(str)
    if referent
      referent.express(str, :tagtype => :Source, :form => :generic )
    else
      self.referent = Referent.express(str, :Source, :form => :generic )
    end
  end

  def recipes
    # The recipes for a site are all those that match the site's references
    RecipeReference.lookup_recipes references.map(&:url), true
  end
end

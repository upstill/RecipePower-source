# encoding: UTF-8
require './lib/uri_utils.rb'
=begin
class Finder < Object
  attr_accessor :label, :path, :attribute
  def initialize label, path, attribute
    self.label = label
    self.path = path
    self.attribute = attribute
    super()
  end

  def self.model_name
    ActiveModel::Name.new Site::Finder
  end
end
=end

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
  attr_accessible :finders_attributes, :sample, :oldname, :ttlcut, :finders, :reviewed, :description # , :subsite, :home, :logo, :oldsite, :scheme, :host, :port
#   serialize :finders, Array

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

  def post_init
    unless id # self.oldsite
      # We need to initialize the fields of the record, starting with site, based on sample
      # Ignore the query for purposes of gleaning the site
      if self.sample = normalize_url(sample)
        # the sample is EITHER a full URL, or a partial path relative to home
        if (uri = safe_parse(sample)).host.blank?
          uri = URI.join( home, sample)
        end
        unless uri.host.blank?
          # Define the site as the link minus the sample (sub)path plus the subsite
          # reflink = "#{host_url(uri.to_s)}#{subsite}".gsub /\/+/, '/'
          self.reference = SiteReference.find_or_initialize(uri.to_s, affiliate: self) # Reference.find_or_initialize reflink, type: "SiteReference", affiliate: self

          # Give the site a provisional name, the host name minus 'www.', if any
          self.name = uri.host.sub(/www\./, '')
        else
          self.errors.add :url, "Can't make sense of URI"
        end
      end
    end
  end

public

  def domain
    host_url home # scheme+"://"+host+((port=="80") ? "" : (":"+port))
  end

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
  
  # Find and return the site wherein the named link is stored
  def self.by_link link
    ref = SiteReference.by_link link
    ref.site || Site.create(:sample=>link) # Should find the same site reference
  end

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
    RecipeReference.affiliates_by_url references.map(&:url)
  end
end

# encoding: UTF-8
require './lib/uri_utils.rb'

class Site < ActiveRecord::Base
  include Collectible
  picable :logo, :thumbnail, "MissingLogo.png"
  linkable :home, :reference

  # site: root of the domain (i.e., protocol + domain); suitable for pattern-matching on a reference URL to glean a set of matching Sites
  # subsite: a path relative to the domain which differentiates among Sites with the same domain (site attribute)
  # home: where the nominal site lives. This MAY be (site+subsite), but in cases of indirection, it may be an entirely
  #      different domain. (See Splendid Table on publicradio.org redirect to splendidtable.org)
  # So, (site+sample) and (site+subsite) should be valid links, but not necessarily (home+sample), since redirection
  #      may alter the path
  # Also, in most cases, site==home (when the domain is home, i.e. subsite is empty); in others, (site+subsite)==home,
  #     and only rarely will home be different from either of those
  attr_accessible :finders_attributes, :sample, :oldname, :ttlcut, :finders, :reviewed, :description, :reference, :references, :name

  belongs_to :referent # See before_destroy method, :dependent=>:destroy

  has_many :finders, :dependent=>:destroy
  accepts_nested_attributes_for :finders, :allow_destroy => true
  
  has_many :feeds, :dependent=>:restrict_with_exception

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
    site.referent.destroy if site.referent && (sibling_sites.count == 1) && (sibling_sites.first.id == site.id)
  end

  # When a site is first created, it needs to have a SiteReference built from its sample attribute
  def post_init
    unless id
      self.sample = normalize_url sample # Normalize the sample
      # Attach relevant references if they haven't been mass-assigned
      self.home = sample if self.references.empty?
      # Give the site a provisional name, the host name minus 'www.', if any
      self.name = domain.sub(/www\./, '') if domain # Creates a corresponding referent
    end
  end

public

  # Make sure that a url(s) map(s) to this site, returning true if any references were added
  def include_url url_or_urls
    (url_or_urls.is_a?(String) ? [url_or_urls] : url_or_urls).any? do |url|
      url = normalize_url url
      # Reject urls that already reference a site
      unless SiteReference.lookup_site(url)
        # Ensure that 1) this url gets back to this site, and 2) it has the longest possible subpath in common with the other references
        target_uri = URI(url)
        target_uri.query = target_uri.fragment = nil # Queries and fragments are ignored in site mappings
        target_path = target_uri.path
        existing_urls = references.map(&:url)
        target_uri.path = existing_urls.inject("") { |memo, ref_url|
          ref_path = URI(ref_url).path
          memo = ((ref_path.length > memo.length) && target_path.match(/^#{ref_path}/)) ? ref_path : memo
        }
        # Add the new references to those of the site, eliminating redundant ones
        new_refs = SiteReference.find_or_initialize(target_uri.to_s, true).keep_if { |candidate| existing_urls.all? { |url| url != candidate.url } }
        unless new_refs.empty?
          self.references = self.references + new_refs
        end
      end
    end
  end

  def self.strscopes matcher
    onscope = block_given? ? yield() : self.unscoped
    [
        onscope.where(%q{"sites"."description" ILIKE ?}, matcher)
    ] + Reference.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:reference => inward} : :reference
      block_given? ? yield(joinspec) : self.joins(joinspec)
    } + Referent.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:referent => inward} : :referent
      block_given? ? yield(joinspec) : self.joins(joinspec)
    }
  end

  def self.joinings assoc_name, matcher, &block
    # block.call(assoc_name).where 'sites.description ILIKE ?', matcher
    block.call(assoc_name => {referent: :tags}).where 'tags.name ILIKE ?', matcher
  end

  # Merge another site into this one, optionally destroying the other
  def absorb other
    # Merge corresponding referents
    self.description = other.description if description.blank?
    if other.referent
      if referent
        referent.absorb other.referent
      else
        self.referent = other.referent
      end
      other.referent = nil
    end
    # Steal feeds
    other.feeds.each { |other_feed|
      other_feed.site = self
      other_feed.save
    }
    super # Let the taggable, collectible, etc. modules do their work
    other.reload # Refreshes, e.g., feeds list prior to deletion
  end


  # Produce a Site for a given url whether one already exists or not
  def self.find_or_create link_or_links
    links = link_or_links.is_a?(String) ? [link_or_links] : link_or_links
    refs = SiteReference.find_or_initialize links
    if refs && refs.first
      refs.first.site || self.create(sample: links.first, references: refs, reference: refs.first )
    end
  end

  def domain
    host_url home
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
    # The recipes for a site are all those that match the site's references
    RecipeReference.lookup_recipes references.map(&:url), true
  end
end

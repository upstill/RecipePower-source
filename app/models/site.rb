# encoding: UTF-8
require './lib/uri_utils.rb'

class Site < ApplicationRecord
  include Taggable # Can be tagged using the Tagging model
  include Collectible
  include Referrable
  include Backgroundable
  backgroundable
  include Pagerefable
  picable :logo, :thumbnail, 'MissingLogo.png'
  pagerefable :home

  def self.mass_assignable_attributes
    super + %i[ description trimmers ]
  end

  has_many :page_refs # Each PageRef refers back to some site based on its path

  serialize :trimmers, Array # An array of CSS selectors used to remove extraneous content

  def dependent_page_refs
    page_refs.where.not id: page_ref_id
  end

  # site: root of the domain (i.e., protocol + domain); suitable for pattern-matching on a reference URL to glean a set of matching Sites
  # subsite: a path relative to the domain which differentiates among Sites with the same domain (site attribute)
  # home: where the nominal site lives. This MAY be (site+subsite), but in cases of indirection, it may be an entirely
  #      different domain. (See Splendid Table on publicradio.org redirect to splendidtable.org)
  # So, (site+sample) and (site+subsite) should be valid links, but not necessarily (home+sample), since redirection
  #      may alter the path
  # Also, in most cases, site==home (when the domain is home, i.e. subsite is empty); in others, (site+subsite)==home,
  #     and only rarely will home be different from either of those
  # attr_accessible :finders_attributes, :oldname, :ttlcut, :finders, :approved, :approved_feeds_count, :feeds_count,
                  # :description, :reference, :references, :name, :page_ref_attributes

  # For reassigning the kind of the page_ref
  accepts_nested_attributes_for :page_ref

  # attr_accessible :sample, :root

  if Rails::VERSION::STRING[0].to_i < 5
    belongs_to :referent, class_name: 'SourceReferent' # See before_destroy method, :dependent=>:destroy
  else
    belongs_to :referent, class_name: 'SourceReferent', optional: true # See before_destroy method, :dependent=>:destroy
  end

  has_many :finders, :dependent=>:destroy
  accepts_nested_attributes_for :finders, :allow_destroy => true
  
  has_many :feeds, :dependent=>:restrict_with_error
  has_many :approved_feeds, -> { where(approved: true) }, :class_name => 'Feed'

  # Sites have an 'approved' bit which clears them for browsing
  # This is because a site can appear for any link, including chef's restaurants, etc.
  # By approving them explicitly (the default is nil), we can keep ahead of the cruft
  scope :approved, -> { where(approved: true) }
  scope :pending, -> { where(approved: nil) }
  scope :hidden, -> { where(approved: false) }

  #...and associate with recipes via the recipe_page_refs that refer back here
  has_many :recipes, :through => :page_refs, :dependent=>:restrict_with_error

  before_validation do |site|
    if site.root.blank? && site.page_ref
      site.root =
          (subpaths(site.home).last if site.home.present? && subpaths(site.home)) ||
              (subpaths(site.sample).first if site.sample.present? && subpaths(site.sample))
    end
  end

  # after_initialize :post_init
  validates_uniqueness_of :root

  after_create do |entity|
    bkg_launch # Start a job going to extract title, etc. from the home page
  end

  after_save do |site|
    # After-save task: reassign this site's entities to another site with a shorter root (set in #root=)
    # Reassign all of our pagerefs as necessary
    if root_changed? # Root has changed
      page_refs.each { |pr|
        if (newsite = Site.find_for pr.url) != pr.site
          pr.site = newsite
          pr.save
        end
      }
      # A given domain may have several sites, even if ones where one is a substring of another.
      # The site for a page_ref should be the one with the longest root.
      # Therefore, at this point we may steal any references from a site that has a shorter path
      if shorter_site = Site.with_subroot_of(root)
        PageRef.where(site: shorter_site).joins(:aliases).where(Alias.url_path_query root).each { |pr|
          # Reassign all PageRefs of the parent which apply here
          pr.update_attribute :site_id, id
        }
      end
    end
  end

  # This is called when the page_ref finishes updating
  def adopt_gleaning
    # Extract elements from the page_ref
    self.logo = page_ref.picurl unless logo.present? || page_ref.picurl.blank?
    self.name = page_ref.title.if_present || URI(page_ref.url).host if name.blank?
    self.description = page_ref.description unless description.present? || page_ref.description.blank?
    gleaning&.results_for('RSS Feed').map { |feedstr| assert_feed feedstr }
    save if persisted? && changed?
  end

  # Most collectibles refer back to their host site via its page_ref; not necessary here
  def site
    self
  end

  protected

  # If this is the last site associated with its referent, destroy the referent
  before_destroy do |site|
    sibling_sites = Site.where(referent_id: site.referent_id)
    site.referent.destroy if site.referent && (sibling_sites.count == 1) && (sibling_sites.first.id == site.id)
  end

public

  def assert_feed url, approved=false
    url = normalize_url url
    feed = (extant = feeds.find_by(url: url)) || Feed.create_with(approved: approved).find_or_create_by(url: url)
    if feed && !feed.errors.any? && !extant
      if feed.approved != approved
        feed.approved = approved
        feed.save
      end
      # Newly created feed => enqueue it and add it to the list
      Delayed::Job.enqueue feed  # New feeds get updated by default
      self.feeds << feed unless feeds.exists?(id: feed.id)
    end
  end

  # When a result from one of the site's finders gets hit, vote it up
  def hit_on_finder label, selector, attribute_name
    attribs = { label: label, selector: selector, attribute_name: attribute_name }
    finder = finders.exists?(attribs) ? finders.where(attribs).first : finders.create(attribs)
    finder.hits += 1
    finder.save
  end

  # When attributes are selected directly and returned as gleaning attributes, assert them into the model
  def gleaning_attributes= attrhash
    super
    return unless attrhash
    if value_hash = attrhash['RSS Feed']
      # The 'value(s)' are a hash of feeds
      value_hash.values.map { |url| assert_feed url, true }
    end
  end

  def self.strscopes matcher
    onscope = block_given? ? yield() : self.unscoped
    a1 = [
        onscope.where(%q{"sites"."description" ILIKE ?}, matcher),
        # onscope.where(%q{"sites"."root" ILIKE ?}, matcher)
    ]
    a2 = PageRef.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:page_ref => inward} : :page_ref
      block_given? ? yield(joinspec) : self.joins(joinspec)
    }
    a3 = Referent.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:referent => inward} : :referent
      block_given? ? yield(joinspec) : self.joins(joinspec)
    }
    a1 + a2 + a3
  end

  # Return a scope for finding references of a given type
  def contents_scope model_class
    model_class == Feed ? feeds : model_class.query_on_path(root)
  end

  # Merge another site into this one, optionally destroying the other
  def absorb other, destroy=true
    # Merge corresponding referents
    return true if other.id == id
    self.description = other.description if description.blank?
    self.sample = other.sample unless safe_parse(sample)
    if other.referent
      if referent
        referent.absorb other.referent
      else
        self.referent = other.referent
      end
      other.referent = nil
    end
    # Steal feeds
    self.feed_ids = feed_ids | other.feed_ids
    other.feeds = []
    # self.page_ref_ids = page_ref_ids | other.page_ref_ids
    prids = page_ref_ids
    other.page_refs.each { |pr| self.page_refs << pr unless prids.include?(pr.id) }
    other.page_refs = []
    super(other) if defined?(super) # Let the taggable, collectible, etc. modules do their work
    other.destroy if destroy
    save
  end

  # Find a site that has a root which is a substring of the given root
  def self.with_subroot_of(root)
    paths = root.split('/')[0..-2].inject([]) { |int, p| int << (int.empty? ? p : "#{int[-1]}/#{p}") }
    Site.where(root: paths).to_a.max_by { |s| s.root.length }
  end

  # do qa when reassigning root
  def root= new_root
    new_root.sub!(/\/$/, '')
    return if new_root == root

    # Find all the existing sites that match this path
    if Site.where(root: new_root).exists?
      errors.add :root, 'must be unique'
      return
    end
    # We need to ensure that PageRefs currently pointing to this site have a good home
    dirs = new_root.split('/')
    base = dirs.shift # Get the host

    # Find a site to which we can reassign associated pagerefs
    # i.e., the one with the longest root that is a substring of the current root
    if root
      # All page refs will still be valid if the new root is a substring of the current one
      # ...but the shorter version may still attract others
      unless Site.with_subroot_of(root) # A site that <could> take all pagerefs as needed
        orphans = dependent_page_refs.joins(:aliases).where.not(Alias.url_path_query new_root).pluck :url
        unless orphans.keep_if { |url| !(s = Site.find_for(url)) || (s.id == id) }.empty?
          # The new root is neither a substring nor a superstring of the existing root.
          # Since we've already established that there's no Site to catch the existing entities, we fail
          errors.add(:root, "would abandon #{orphans.count} out of #{dependent_page_refs.count} existing entities")
          return
        end
      end
    end
    super
  end

  # Return a scope for sites that could apply to the given link
  def self.applies_to_url link
    return nil unless links = subpaths(link) # URL doesn't parse
    # Find a site, if any, based on the longest subpath of the URL
    Site.where root: links # Scope for all sites whose root matches a subpath of the url...
  end

  def self.find_for link
    # Find a site, if any, based on the longest subpath of the URL
    matches = applies_to_url link
    if matches.present? # Of all sites whose root matches a subpath of the url...
      # ...return the one with the longest root
      matches.inject(matches.first) { |result, site|
        site.root.length > result.root.length ? site : result
      }
    end
  end

  # Produce a Site that maps to a given url(s) whether one already exists or not
  def self.find_or_create_for link

    # Look first for existing sites on any of the links
    if site = self.find_for(link)
      return site
    end

    if inlinks = subpaths(link)
      # return self.create(home: host_url(link), root: inlinks.first, sample: link)
        return self.find_or_create host_url(link), root: inlinks.first, sample: link
    end
    self.find_or_create host_url(link), sample: link
  end

  # Produce a Site for a given url(s) whether one already exists or not
  def self.find_or_create homelink, do_glean = true, options={}
    do_glean, options = true, do_glean if do_glean.is_a?(Hash)
    if uri = options[:root] || cleanpath(homelink) # URL parses
      # Find a site, if any, based on the longest subpath of the URL
      Site.find_by(root: uri) || Site.create({sample: homelink}.merge(options).merge(root: uri, home: homelink))
    end
  end

  alias_method :ohome_eq, :'home='
  # We need to point the page_ref back to us so that it doesn't create a redundant site.
  def home=(url)
    revised = ohome_eq(url)
    page_ref.site = self
    page_ref.kind = :site
    revised
  end

  # Produce a Site for a given url(s) whether one already exists or not,
  # WITHOUT SAVING IT
  def self.find_or_initialize homelink, options={}
    if uri = options[:root] || cleanpath(homelink) # URL parses
      # Find a site, if any, based on the longest subpath of the URL
      Site.find_by(root: uri) ||
      Site.new( { sample: homelink }.merge(options).merge(root: uri, home: homelink) )
    end
  end

  def domain
    host_url home
  end

  def name
    referent.name if referent
  end

  def name=(str)
    return unless str.present?
    if referent
      referent.express(str, :tagtype => :Source, :form => :generic )
    else
      self.referent = Referent.express(str, :Source, :form => :generic)
    end
  end

end

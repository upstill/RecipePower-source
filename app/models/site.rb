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

  # We track attributes from Gleanings and MercuryResult except URL
  include Trackable
  attr_trackable :home, :name, :logo, :description, :rss_feed

  # :grammar_mods: a hash of modifications to the parsing grammar for the site
  serialize :grammar_mods, Hash

  @@IPURL = @@IPSITE = nil

  def self.mass_assignable_attributes
    super + [ :description, :trimmers,
              :selector_string, # Defines a Finder for Content
              :trimmers_str, # Enumerates selectors for content to cut from page
              :rcplist_selector, # Defines the beginning of a recipe on the page
              :inglist_selector, :ingline_selector, # Locate ingredients in the recipe
              :title_selector # Finds the title within a recipe
    # :recipe_selector
            ]
  end

  has_many :page_refs # Each PageRef refers back to some site based on its path

  serialize :trimmers, Array # An array of CSS selectors used to remove extraneous content

  ## Define the virtual attribute :trimmers_str for fetching and assigning trimmers as a string
  def trimmers_str
    trimmers.join "\n"
  end

  def trimmers_str= str
    # We don't care what kind of whitespace or how long a sequence separates the selectors
    self.trimmers = str.split /\s+/
  end

  ## Define the virtual attribute :trimmers_str for fetching and assigning trimmers as a string
  def rcplist_selector
    get_selector_for :rp_recipelist, :match, :at_css_match
  end

  def rcplist_selector= str
    # We don't care what kind of whitespace or how long a sequence separates the selectors
    set_selector_for str, :rp_recipelist, :match, :at_css_match
  end

  def method_missing name, *args
    if name.to_s.match /(\w*)_selector(=)?$/
      token = ('rp_'+$1).to_sym
      if $2 == '='
        set_selector_for args.first, token, :in_css_match
      else
        get_selector_for token, :in_css_match
      end
    else
      super if defined?(super)
    end
  end

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

  has_many :finders, :dependent=>:destroy, autosave: true
  accepts_nested_attributes_for :finders, :allow_destroy => true
  # You might think you could do this with query methods, but those fail to find records that haven't been
  # persisted. That extends to #finders UNLESS they are converted to an Array.
  # So these methods work whether the members have been persisted or not--at the cost of a potential query
  def finder_for label
    finders.find { |f| f.label == label }
  end

  def finders_for label
    finders.to_a.keep_if { |f| f.label == label }
  end

  ## Define the virtual attribute :selector_str for fetching and assigning Content selector as a string
  def selector_string
    finder_for('Content')&.selector.if_present || ''
  end

  def selector_string= str
    if extant = finder_for('Content')
      extant.selector = str
    else
      finders.build label: 'Content', attribute_name: 'html', selector: str
    end
  end

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
    # If either the root or the home haven't been set, derive one from the other
    if site.attribute_present? :root
      site.home = site.home
    elsif site.attribute_present? :home
      site.root = site.root
    end
  end

  # after_initialize :post_init
  validates_uniqueness_of :root

  after_create { |site| site.request_attributes :name, :logo } # Start a job going to extract title, etc. from the home page

  after_save do |site|
    bkg_launch if site.needed_attributes.present?
    # After-save task: reassign this site's entities to another site with a shorter root (set in #root=)
    # Reassign all of our pagerefs as necessary
    if saved_change_to_root? # Root has changed
      page_refs.each do |pr|
        if (newsite = SiteServices.find_for pr.url) != pr.site
          page_refs.delete pr
          newsite.page_refs << pr
        end
      end
      # A given domain may have several sites, even if ones where one is a substring of another.
      # The site for a page_ref should be the one with the longest root.
      # Therefore, at this point we may steal any references from a site that has a shorter path
      if shorter_site = Site.with_subroot_of(root)
        PageRef.where(site: shorter_site).joins(:aliases).where(Alias.url_path_query root).each { |pr|
          # Reassign all PageRefs of the parent which apply here
          shorter_site.page_refs.delete pr
          page_refs << pr
        }
      end
    end
  end

  ######### Trackable overrides ############
  ############## Trackable ############
  # Request attributes of other objects
  def request_dependencies *newly_needed
    page_ref_attribs = newly_needed.collect { |my_attrib|
      # Provide the attribute that will receive the value for the given PageRef attribute
        case my_attrib
        when :name
          :title
        when :logo
          :picurl
        when :home
          :url
        else
          my_attrib
        end
    }
    page_ref || build_page_ref
    page_ref.request_attributes *page_ref_attribs
  end

  # Get the available attributes from the PageRef
  def adopt_dependencies
    # Translate what the PageRef is offering into our attributes
    accept_attribute :logo, page_ref.picurl if page_ref.picurl_ready?
    accept_attribute :name, page_ref.title if page_ref.title_ready?
    accept_attribute :description, page_ref.description if page_ref.description_ready?
    page_ref.rss_feeds.map { |feedstr| assert_feed feedstr } if page_ref.rss_feeds_ready?
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
    feed = (extant = feeds.find_by(url: url)) || Feed.create_with(approved: approved, site: self).find_or_create_by(url: url)
    if feed&.errors.empty? && !extant
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
    extant = finders_for(label).find { |f| f.selector == selector && f.attribute_name == attribute_name }
    finder = extant || finders.create(attribs)
    # finder = finders.exists?(attribs) ? finders.where(attribs).first : finders.create(attribs)
    finder.hits += 1
    finder.save
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
    old_root = attributes[:root]
    return if new_root == old_root

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
    if old_root
      # All page refs will still be valid if the new root is a substring of the current one
      # ...but the shorter version may still attract others
      unless Site.with_subroot_of(old_root) # A site that <could> take all pagerefs as needed
        orphans = dependent_page_refs.joins(:aliases).where.not(Alias.url_path_query new_root).pluck :url
        unless orphans.keep_if { |url| !(s = SiteServices.find_for(url)) || (s.id == id) }.empty?
          # The new root is neither a substring nor a superstring of the existing root.
          # Since we've already established that there's no Site to catch the existing entities, we fail
          errors.add(:root, "would abandon #{orphans.count} out of #{dependent_page_refs.count} existing entities")
          return
        end
      end
=begin
  ## This is now part of after_save procedure so corrected page_refs have a
    else
      if osite = Site.with_subroot_of(new_root)
        osite.page_refs.where('url ILIKE ?', "%#{new_root}").not(id: page_ref_id).each do |newref|
          # Move refs that match new root from old site to here
          osite.page
        end
      end
=end
    end
    super
  end

  # Provide fallback for root in case it hasn't been set
  def root
    super ||
    if page_ref
      (subpaths(home).last if home.present? && subpaths(home)) ||
          (subpaths(sample).first if sample.present? && subpaths(sample))
    end
  end

  def home
    page_ref&.url || "http://#{self[:root]}"
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
      self.referent = Referent.express(str, :Source, :form => :generic).becomes SourceReferent
    end
  end

  private

  def get_selector_for *tokens
    hsh = grammar_mods # Start at the top level
    tokens.each do |token|
      return unless hsh[token]
      hsh = hsh[token]
    end
    return hsh
  end

  def set_selector_for str, *tokens
    hsh = grammar_mods # Start at the top level
    tokens[0...-1].each do |token|
      if hsh[token]
        hsh = hsh[token]
      else
        hsh = (hsh[token] = {})
      end
    end
    token = tokens.last
    if str.present?
      hsh[token] = str
    else
      hsh.delete token
    end
  end

end

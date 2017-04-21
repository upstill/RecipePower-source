# encoding: UTF-8
require './lib/uri_utils.rb'
require 'referent.rb'

class Site < ActiveRecord::Base
  include Collectible
  # TODO: pull the switch by making sites pagerefable rather than linkable
  include Referrable
  # linkable :home, :reference, gleanable: true
  include Pagerefable
  picable :logo, :thumbnail, 'MissingLogo.png'
  pagerefable :home, gleanable: true # belongs_to :page_ref #

  has_many :page_refs # Each PageRef refers back to some site based on its path

  # site: root of the domain (i.e., protocol + domain); suitable for pattern-matching on a reference URL to glean a set of matching Sites
  # subsite: a path relative to the domain which differentiates among Sites with the same domain (site attribute)
  # home: where the nominal site lives. This MAY be (site+subsite), but in cases of indirection, it may be an entirely
  #      different domain. (See Splendid Table on publicradio.org redirect to splendidtable.org)
  # So, (site+sample) and (site+subsite) should be valid links, but not necessarily (home+sample), since redirection
  #      may alter the path
  # Also, in most cases, site==home (when the domain is home, i.e. subsite is empty); in others, (site+subsite)==home,
  #     and only rarely will home be different from either of those
  attr_accessible :finders_attributes, :oldname, :ttlcut, :finders, :approved, :approved_feeds_count, :feeds_count,
                  :description, :reference, :references, :name, :gleaning

  attr_accessible :sample, :root

  belongs_to :referent, class_name: 'SourceReferent' # See before_destroy method, :dependent=>:destroy

  has_many :finders, :dependent=>:destroy
  accepts_nested_attributes_for :finders, :allow_destroy => true
  
  has_many :feeds, :dependent=>:restrict_with_error
  has_many :approved_feeds, -> { where(approved: true) }, :class_name => 'Feed'

  # Make an association with each type of PageRef that references this site
  PageRef.types.each { |type| has_many "#{type}_page_refs".to_sym, :dependent=>:restrict_with_error }

  #...and associate with recipes via the recipe_page_refs that refer back here
  has_many :recipes, :through => :recipe_page_refs, :dependent=>:restrict_with_error

  before_validation do |site|
    if site.root.blank? && site.page_ref
      site.root =
          (subpaths(site.home).last if site.home.present? && subpaths(site.home)) ||
              (subpaths(site.sample).first if site.sample.present? && subpaths(site.sample))
    end
  end

  # after_initialize :post_init
  validates_uniqueness_of :root

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
      # Steal any references from a site that has a shorter path
      if shorter_site = Site.with_subroot_of(root)
        shorter_site.page_refs.where(PageRef.url_path_query root).each { |pr|
          # Reassign all PageRefs of the parent which apply here
          pr.site = self
          pr.save
        }
      end
      reload
    end
  end

  # Most collectibles refer back to their host site; not necessary here
  def site
    self
  end

  protected

  # If this is the last site associated with its referent, destroy the referent
  before_destroy do |site|
    sibling_sites = Site.where(referent_id: site.referent_id)
    site.referent.destroy if site.referent && (sibling_sites.count == 1) && (sibling_sites.first.id == site.id)
  end

=begin
  # When a site is first created, it needs to have a SiteReference built from its sample attribute
  def post_init
    unless id
      self.sample = normalize_url sample # Normalize the sample
      # Attach relevant references if they haven't been mass-assigned
      self.home = page_ref.url # sample if self.references.empty?
      # Give the site a provisional name, the host name minus 'www.', if any
      self.name = domain.sub(/www\./, '') if domain # Creates a corresponding referent
    end
  end
=end

public

  def assert_feed url, approved=false
    url = normalize_url url
    feed = (existed = feeds.exists?(url: url)) ? feeds.where(url: url).first : feeds.create(url: url, approved: approved)
    Delayed::Job.enqueue feed if feed && !existed # New feeds get updated by default
    if feed.approved != approved
      feed.approved = approved
      feed.save
    end
  end

  # When a result from one of the site's finders gets hit, vote it up
  def hit_on_finder label, selector, attribute_name
    attribs = { label: label, selector: selector, attribute_name: attribute_name }
    finder = finders.exists?(attribs) ? finders.where(attribs).first : finders.create(attribs)
    finder.hits += 1
    finder.save
  end

=begin
  # Make sure that a url(s) map(s) to this site, returning true if any references were added
  def include_url url_or_urls, in_full=false
    (url_or_urls.is_a?(String) ? [url_or_urls] : url_or_urls).any? do |url|
      url = normalize_url url
      # Reject urls that already reference a site
      if (other = SiteReference.lookup_site(url)) && (other != self) # Don't change references
        errors.add :home, "That url is already associated with the site '#{other.name}'."
        return
      end
      # Ensure that 1) this url gets back to this site, and 2) it has the longest possible subpath in common with the other references
      target_uri = URI(url)
      target_uri.query = target_uri.fragment = nil # Queries and fragments are ignored in site mappings
      target_path = target_uri.path
      existing_urls = references.map(&:url)
      # Of all the urls in the extant references, determine the longest subpath of the target
      target_uri.path = existing_urls.inject('') { |memo, ref_url|
        ref_path = URI(ref_url).path
        (ref_path.length > memo.length) && target_path.match(/^#{ref_path}/) ? ref_path : memo
      } unless in_full
      # Add the new references to those of the site, eliminating redundant ones
      new_refs = SiteReference.find_or_initialize(target_uri.to_s, true).to_a.keep_if { |candidate|
        !existing_urls.include?(candidate.url)
      }
      unless new_refs.empty?
        self.references = self.references + new_refs
      end
    end
  end
=end

  def self.strscopes matcher
    onscope = block_given? ? yield() : self.unscoped
    a1 = [
        onscope.where(%q{"sites"."description" ILIKE ?}, matcher)
    ]
    a2 = SitePageRef.strscopes(matcher) { |inward=nil|
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
    self.page_ref_ids = page_ref_ids | other.page_ref_ids
    other.page_refs = []
    super other if defined?(super) # Let the taggable, collectible, etc. modules do their work
    other.destroy if destroy
    save
  end

  def self.with_subroot_of(root)
    dirs = root.sub(/\/$/,'').split('/')
    base = dirs.shift # Get the host
    found = Site.where('root LIKE ?', base + '%').inject(nil) { |result, site|
      if (site.root.length < root.length) && (!result || (site.root.length > result.root.length))
        site
      else
        result
      end
    }
    found
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
        orphans = page_refs.where.not(PageRef.url_path_query new_root).pluck :url
        unless orphans.keep_if { |url| !(s = Site.find_for(url)) || (s.id == id)  }.empty?
          # The new root is neither a substring nor a superstring of the existing root.
          # Since we've already established that there's no Site to catch the existing entities, we fail
          errors.add(:root, "would abandon #{orphans.count} out of #{page_refs.count} existing entities")
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
    if (matches = applies_to_url(link)).present? # Of all sites whose root matches a subpath of the url...
      # ...return the one with the longest root
      matches.inject(matches.first) { |result, site|
        site.root.length > result.root.length ? site : result
      }
    end
  end

  # Produce a Site that maps to a given url(s) whether one already exists or not
  def self.find_or_create_for link_or_links
    links = link_or_links.is_a?(Array) ? link_or_links : [link_or_links]

    # Look first for existing sites on any of the links
    links.each { |link|
      if site = self.find_for(link)
        return site
      end
    }
    links.each { |link|
      if inlinks = subpaths(link)
        # return self.create(home: host_url(link), root: inlinks.first, sample: link)
        return self.find_or_create host_url(link), root: inlinks.first, sample: link
      end
    }
    link = links.first
    self.find_or_create host_url(link), sample: link
  end

  # Produce a Site for a given url(s) whether one already exists or not
  def self.find_or_create homelink, do_glean = true, options={}
    do_glean, options = true, do_glean if do_glean.is_a?(Hash)
    if uri = options[:root] || cleanpath(homelink) # URL parses
      # Find a site, if any, based on the longest subpath of the URL
      if site = Site.find_by(root: uri)
        return site
      else
        site = Site.new( { sample: homelink }.merge(options).merge(root: uri, home: homelink) )
        # TODO: Should be eliminable with switchover to pagerefable
        unless site.page_ref
          spr = PageRef::SitePageRef.fetch homelink
          site.page_ref = spr unless spr.errors.any?
        end
        unless site.referent # Could have been generated with the :name option
          # Need to give it a name
          if (spr = site.page_ref) && spr.title.present?
            site.name = spr.title
          end
        end
        site.glean # Grab page in background
        site.save
        return site
      end
    end
  end

  # Produce a Site for a given url(s) whether one already exists or not,
  # WITHOUT SAVING IT
  def self.find_or_initialize homelink, options={}
    if uri = options[:root] || cleanpath(homelink) # URL parses
      # Find a site, if any, based on the longest subpath of the URL
      if site = Site.find_by(root: uri)
        return site
      else
        site = Site.new( { sample: homelink }.merge(options).merge(root: uri, home: homelink) )
        # TODO: Should be eliminable with switchover to pagerefable
        unless site.page_ref
          spr = PageRef::SitePageRef.fetch homelink
          site.page_ref = spr unless spr.errors.any?
        end
        unless site.referent # Could have been generated with the :name option
          # Need to give it a name
          if (spr = site.page_ref) && spr.title.present?
            site.name = spr.title
          end
        end
        return site
      end
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

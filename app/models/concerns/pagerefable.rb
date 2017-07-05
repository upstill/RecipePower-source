require './lib/uri_utils.rb'
require 'page_ref.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class

module Pagerefable
  extend ActiveSupport::Concern

  module ClassMethods

    def pagerefable(url_attribute, options = {})
      ref_type = "#{self.to_s}PageRef"

      # The url attribute is accessible, but access is through an instance method that
      # defers to a Reference
      attr_accessible url_attribute, :page_ref

      # has_one :page_ref, -> { where(type: ref_type).order('canonical DESC') }, foreign_key: 'affiliate_id', class_name: ref_type, :dependent=>:destroy
      belongs_to :page_ref, class_name: self.to_s+'PageRef', foreign_key: 'page_ref_id', validate: true
      # delegate :glean, :'glean!', :to => :page_ref

      has_one :site, :through => :page_ref
      # A gleaning is the result of cracking a page. The gleaning for a linkable is used mainly to
      # peg successful hits on finders. (Sites have an associated set of finders, on which they
      # remember successful hits)
      has_one :gleaning, :through => :page_ref
      accepts_nested_attributes_for :gleaning

=begin
      if options[:gleanable]
        has_one :gleaning, :as => :entity
        accepts_nested_attributes_for :gleaning
      end
=end

      self.class_eval do
        # For the one attribute used to index the entity, provide access to its name for use in class and instance methods
        define_singleton_method :url_attribute do
          url_attribute
        end

        # The class gets two finder methods, for finding by exact url, and matching a root path (host+path)
        # Locate an entity by its url. This could be the canonical url or any alias
        define_singleton_method :find_by_url do |url|
          page_ref_class = (self.to_s + 'PageRef').constantize
          self.joins(:page_ref).find_by(page_ref_class.url_query url)
        end

        # Find entitites whose url matches the given path (which includes the host)
        define_singleton_method :query_on_path do |urpath|
          page_ref_class = (self.to_s + 'PageRef').constantize
          self.joins(:page_ref).where(page_ref_class.url_path_query urpath)
        end

      end

      self.instance_eval do

        # URL, PageRef -> PageRef
        # Assign the URL to be used in accessing the entity. In the case of a successful redirect, this <may>
        # be different from the one provided
        define_method "#{url_attribute}=" do |url|
          klass = ref_type.constantize
          pr = klass.fetch url
          # Now we have a pageref which has the url, either in the attribute or the aliases
=begin
          unless (pr.url == url) || pr.good?
            # The given url must be among the aliases => take it out and fetch on its own
            pr.aliases -= [ url ]
            pr.save
            pr = klass.fetch url
          end
=end
          # errors.add(:url, pr.errors[url_attribute]) if pr.errors[url_attribute].present?
          self.page_ref = pr
          # pr.glean unless self.errors.any? # Update the gleaning data, if any
          url
        end

        define_method url_attribute do
          # This will cause an exception for entities without a corresponding reference
          page_ref ? page_ref.url : (super() if self.has_attribute?(url_attribute))
        end

      end
    end # Pagerefable

  end


  def self.included(base)
    base.extend(ClassMethods)
  end

  public

  # Glean info from the page in background as a DelayedJob job
  # force => do the job even if it was priorly complete
  def glean force=false
    return if dj # Already queued
    # Only update the page_ref as necessary
    bkg_enqueue page_ref.glean(force) || force # Do the processing no matter what
  end

  # Glean info synchronously, i.e. don't return until it's done
  # force => do the job even if it was priorly complete
  def glean! force=false
    if dj
      bkg_go
    elsif force || virgin?
      page_ref.glean! force
      bkg_go true
    end
  end

  # The site performs its delayed job by forcing the associated page_ref to do its job (synchronously)
  def perform
    bkg_execute do
      page_ref.glean! # Finish doing any necessary gleaning of the page_ref
      true
    end
    adopt_gleaning if good?
    good?
  end

  def ensure_site
    (page_ref.site ||= Site.find_or_create_for(page_ref.url)) if page_ref
  end

  def url_attribute
    self.class.url_attribute if self.class.respond_to? :url_attribute
  end

  # Return the human-readable name for the recipe's source
  def sourcename
    site ? site.name : "Entity #{self.class.to_s} ##{id} has no site"
  end

  # Return the URL for the recipe's source's home page
  def sourcehome
    site ? site.home : '#'
  end

  # One linkable is being merged into another => transfer PageRefs
  def absorb other
    return true if !other.page_ref || (other.id == id)
    puts "PageRef ##{page_ref ? page_ref.id : '<null>'} absorbing #{other.page_ref ? other.page_ref.id : '<null>'}"
    if page_ref
      PageRefServices.new(page_ref).absorb other.page_ref
    else
      self.page_ref = other.page_ref
    end
    super if defined? super
  end

  def gleaning_attributes= attrhash
    gleaning.hit_on_attributes attrhash, site if gleaning && attrhash
  end

end

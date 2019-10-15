require './lib/uri_utils.rb'
require 'page_ref.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class

module Pagerefable
  extend ActiveSupport::Concern

  module ClassMethods

    def mass_assignable_attributes keys=[]
      [ self.url_attribute, {:page_ref_attributes => %i{ kind id } } ].compact + (defined?(super) ? super : [])
    end

    def pagerefable(url_attribute, options = {})

      # The url attribute is accessible, but access is through an instance method that
      # defers to a Pageref
      # attr_accessible url_attribute, :page_ref

      if Rails::VERSION::STRING[0].to_i < 5
        belongs_to :page_ref, validate: true, autosave: true
      else
        belongs_to :page_ref,
                   validate: true,
                   autosave: true,
                   optional: true # Is not required
      end

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
          self.joins(:page_ref => :aliases).find_by Alias.url_query(url)
          # self.joins(:page_ref).find_by(PageRef.url_query url)
        end

        # Include other parameters in the query for a record
        define_singleton_method :find_by_url_and do |params|
          url = params[:url]
          scope = params.count > 1 ? self.where(params.except :url) : self
          scope.joins(:page_ref => :aliases).find_by(Alias.url_query url)
        end

        # Find entities whose url matches the given path (which includes the host)
        define_singleton_method :query_on_path do |urpath|
          self.joins(:page_ref => :aliases).where(Alias.url_path_query urpath)
        end

      end

      self.instance_eval do

        # URL, PageRef -> PageRef
        # Assign the URL to be used in accessing the entity. In the case of a successful redirect, this <may>
        # be different from the one provided
        define_method "#{url_attribute}=" do |url|
          unless page_ref && page_ref.answers_to?(url)
            if pr = PageRef.fetch(url)
              # pr.glean unless self.errors.present? # Update the gleaning data, if any
              self.page_ref = pr
            else
              self.errors.add :url, 'can\'t be used'
            end
          end
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

  # Glean info synchronously, i.e. don't return until it's done
  # force => do the job even if it was priorly complete
  def bkg_land force=false
    page_ref.bkg_land force if page_ref # finish the page_ref gleaning
    super force
  end

  # The site performs its delayed job by forcing the associated page_ref to do its job (synchronously)
  def perform
    if page_ref # Finish doing any necessary gleaning of the page_ref
      page_ref.bkg_land
      adopt_gleaning if page_ref.good?
      save if persisted? && changed?
    end
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

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
          self.joins(:page_ref => :aliases).where(Alias.url_path_query urpath).distinct
        end

      end

      self.instance_eval do
        # URL, PageRef -> PageRef
        # Assign the URL to be used in accessing the entity. In the case of a successful redirect, this <may>
        # be different from the one provided
        define_method "#{url_attribute}=" do |url_or_pr|
          if url_or_pr.is_a? PageRef
            self.page_ref = url_or_pr
            return page_ref.url
          end
          if page_ref
            if page_ref.acceptable_url?(url_or_pr) { |errmsg| self.errors.add :url, "can't be used: #{errmsg}" }
              page_ref.url = url_or_pr
            end
          else
            self.page_ref = PageRef.fetch url_or_pr
            if !page_ref || page_ref.errors.any?
              self.errors.add :url, "can't be used: #{page_ref&.errors&.full_messages}"
            end
          end
          url_or_pr
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

  def site
    page_ref&.site
  end

  # The backgroundable performs its delayed job by forcing the associated page_ref to do its job
  # (synchronously if necessary)
  def perform
    page_ref.ensure_attributes
    if page_ref.bad?
      err_msg = "Page at '#{page_ref.url}' can't be gleaned: PageRef ##{page_ref.id} sez:\n#{page_ref.error_message}"
      errors.add :url, err_msg
      raise err_msg if page_ref.dj # PageRef is ready to try again => so should we be, so restart via Delayed::Job
    end
    super if defined?(super)
  end

  def ensure_site
    (page_ref.site ||= SiteServices.find_or_build_for(page_ref)) if page_ref
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
    page_ref&.gleaning.hit_on_attributes attrhash, site if page_ref&.gleaned? && attrhash
  end

end

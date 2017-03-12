require './lib/uri_utils.rb'
require 'page_ref.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class

module Pagerefable
  extend ActiveSupport::Concern

  module ClassMethods

    def pagerefable(url_attribute, reference_association=:page_ref, options = {})
      reference_association, options = :page_ref, reference_association if reference_association.is_a? Hash
      reference_association = reference_association.to_sym
      ref_type = "#{self.to_s}PageRef"

      # The url attribute is accessible, but access is through an instance method that
      # defers to a Reference
      attr_accessible url_attribute, reference_association

      # has_one reference_association, -> { where(type: ref_type).order('canonical DESC') }, foreign_key: 'affiliate_id', class_name: ref_type, :dependent=>:destroy
      belongs_to reference_association, class_name: 'PageRef', foreign_key: 'page_ref_id', validate: true

      has_one :site, :through => reference_association

      if options[:gleanable]
        # A gleaning is the result of cracking a page. The gleaning for a linkable is used mainly to
        # peg successful hits on finders. (Sites have an associated set of finders, on which they
        # remember successful hits)
        has_one :gleaning, :as => :entity
        accepts_nested_attributes_for :gleaning
      end

      self.class_eval do
        # For the one attribute used to index the entity, provide access to its name for use in class and instance methods
        define_singleton_method :url_attribute do
          url_attribute
        end

        # The class gets two finder methods, for finding by exact url, and matching a root path (host+path)
        # Locate an entity by its url. This could be the canonical url or any alias
        define_singleton_method :find_by_url do |url|
          page_ref_class = (self.to_s + 'PageRef').constantize
          self.joins(reference_association).find_by(page_ref_class.url_query url)
        end

        # Find entitites whose url matches the given path (which includes the host)
        define_singleton_method :query_on_path do |urpath|
          page_ref_class = (self.to_s + 'PageRef').constantize
          self.joins(reference_association).where(page_ref_class.url_path_query urpath)
        end
      end

      self.instance_eval do

        if options[:gleanable]
          # Glean info from the page in background as a DelayedJob job
          # force => do the job even if it was priorly complete
          define_method 'glean' do |refresh=false|
            create_gleaning entity: self unless gleaning
            # force ? gleaning.bkg_requeue : gleaning.bkg_enqueue
            gleaning.bkg_enqueue refresh
          end

          # Glean info synchronously, i.e. don't return until it's done
          # force => do the job even if it was priorly complete
          define_method 'glean!' do |refresh=false|
            create_gleaning entity: self unless gleaning
            gleaning.bkg_go refresh
          end
        end

        # URL, PageRef -> PageRef
        # Assign the URL to be used in accessing the entity. In the case of a successful redirect, this <may>
        # be different from the one provided
        define_method "#{url_attribute}=" do |url|
          klass = ref_type.constantize
          pr = klass.fetch url
          # Now we have a pageref which has the url, either in the attribute or the aliases
          unless (pr.url == url) || pr.good?
            # The given url must be among the aliases => take it out and fetch on its own
            pr.aliases -= [ url ]
            pr.save
            pr = klass.fetch url
          end
          # errors.add(:url, pr.errors[url_attribute]) if pr.errors[url_attribute].present?
          self.page_ref = pr
          glean(true) if !self.errors.any? && respond_to?(:gleaning) && gleaning # Update the gleaning data, if any
          url
        end

        define_method(url_attribute) do
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

  def ensure_site
    (page_ref.site ||= Site.find_or_create_for(page_ref.url)) if page_ref
  end

  def url_attribute
    self.class.url_attribute if self.class.respond_to? :url_attribute
  end

  # Return the human-readable name for the recipe's source
  def sourcename
    if respond_to?(:site) && site
      site.name
    else
      "Entity #{self.class.to_s} ##{id} has no site"
    end
  end

  # Return the URL for the recipe's source's home page
  def sourcehome
    (respond_to?(:site) && site) ? site.home : '#'
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

end

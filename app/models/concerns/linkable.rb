require './lib/uri_utils.rb'
require 'reference.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class
module Linkable
  extend ActiveSupport::Concern

  module ClassMethods

    # Make an attribute of the class linkable, i.e., it contains a URL which is unique to the class,
    # and which is supplanted by a Reference object, except in the case of the Reference class.
    # Options (the first two of which may be given positionally or by name in the options hash):
    # ref_attribute: a symbol for the attribute carrying a Reference object
    # as: the type of Reference that is to contain (URLs are only unique within a type)
    # href_attribute: a secondary URL attribute which can be used to complete a primary URL (i.e., in
    #   the case of images, which may have a relative path)
    # site_from: specifies an attribute that can be used to look up the site associated with the URL
    #   (only matters for classes with multiple linkable attributes)


    # linkable declares a url attribute by which the given entity may be found. An entity may
    # be referenced by multiple URLS but each URL leads to at most one entity.
    # The URL may or may not be defined by a corresponding Reference
    # options[:as]: the class which the referent keeps as an affiliate
    def linkable(url_attribute, reference_association, options = {})
      reference_association_pl = reference_association.to_s.pluralize.to_sym
      reference_association = reference_association.to_sym
      ref_type = options[:as] || "#{self.to_s}Reference"

      # The url attribute is accessible, but access is through an instance method that
      # defers to a Reference
      attr_accessible url_attribute

      # Can get back to references this way:
      has_many reference_association_pl, -> { where type: ref_type }, foreign_key: "affiliate_id", class_name: ref_type
      has_one reference_association, -> { where type: ref_type, canonical: true }, foreign_key: "affiliate_id", class_name: ref_type

      self.class_eval do
        unless options[:as]
          # For the one attribute used to index the entity, provide access to its name for use in class and instance methods
          define_singleton_method :url_attribute_name do
            url_attribute
          end

          # Critical method to ensure no two linkables of the same class [offset] have the same reference
          define_singleton_method :find_or_initialize do |url, params = {}|
            # URL may be passed as a parameter or in the params hash
            url_attribute_name = self.url_attribute_name
            if url.is_a? Hash
              params = url
              url = params[url_attribute_name]
            else
              params[url_attribute_name] = url
            end
            if url.blank? # Check for non-empty URL
              obj = self.new params # Initialize a record just to report the error
              obj.errors.add url_attribute_name, "can't be blank"
            else
              # Normalize the url for lookup
              ref = Reference.find_or_initialize(type: "#{self.to_s}Reference", url: url)
              if ref.affiliate_id # Already referred to
                ref.affiliate
              else
                ref.affiliate = obj = self.new(params)
                ref.save
              end
            end
            obj
          end

          define_singleton_method :find_or_create do |url, params={}|
            obj = self.find_or_initialize url, params
            obj.save unless obj.id || obj.errors.any?
            obj
          end
        end
      end

      self.instance_eval do

        # Define singleton getter and setter methods for the URL, using a reference
        define_method "#{url_attribute}=" do |pu|
          # Since we can't modify references once created, we can only assert a new
          # URL by resort to a new reference
          oldref = self.method(reference_association).call
          self.method(:"#{reference_association}=").call Reference.find_or_initialize(pu, type: ref_type, affiliate: self)
          if oldref != self.method(reference_association).call
            if oldref
              oldref.canonical = false
              oldref.affiliate_id = id
              oldref.save
            end
          end
          if self.has_attribute? url_attribute
            # Set the old url attribute if it still exists
            super pu
          end
          pu
        end

        define_method(url_attribute) do
          # This will cause an exception for entities without a corresponding reference
          ((reference = self.method(reference_association).call) && reference.url) || super()
        end

        unless options[:as]
          # The site for a referenced object
          define_method :site do
            @site ||=
                (url = self.method(url_attribute).call) &&
                    (sr = SiteReference.by_link(url)) &&
                    sr.site
          end
        end

      end
    end # Linkable
  end # ClassMethods

  def self.included(base)
    base.extend(ClassMethods)
  end

  public

  # Return the human-readable name for the recipe's source
  def sourcename
    site.name
  end

  # Return the URL for the recipe's source's home page
  def sourcehome
    site.home_page
  end

end

require './lib/uri_utils.rb'
require 'reference.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class

# The mapping between URLs (expressed in References) and entities is many-to-one: many URLs
# can point to the same entity (in particular, if a website redirects a request, both the
# original and redirected URLs/References get applied to the same entity) but only one entity
# can be associated with any given URL.
module Linkable
  extend ActiveSupport::Concern

  module ClassMethods

    # Make an attribute of the class linkable, i.e., it contains a URL which is unique within the class,
    # and which is supplanted by a Reference object.
    # Options (the first two of which may be given positionally or by name in the options hash):
    # ref_attribute: a symbol for the attribute carrying a Reference object
    # as: the type of Reference that is to contain (URLs are only unique within a type)
    # href_attribute: a secondary URL attribute which can be used to complete a primary URL (i.e., in
    #   the case of images, which may have a relative path)
    # site_from: specifies an attribute that can be used to look up the site associated with the URL
    #   (only matters for classes with multiple linkable attributes)


    # linkable declares 1) a url attribute by which the given entity may be found, and 2) a polymorphic
    # association for the corresponding reference. Generally, the url is actually stored in the reference,
    # but for backward compatibility the url may also be found in the entity.
    #
    # Any entity may be referenced by multiple URLS but each URL leads to at most one entity. References
    # have such affiliates for entities like recipes and sites that have more information than the URL. The
    # type of the reference is constructed from the type of the entity plus "Reference", e.g. "RecipeReference"
    # is a reference that has a Recipe as its extension, and is held by a Recipe.

    # References may also be without affiliate for things like definitions, whose information is solely
    # external, and images, which are captured from elsewhere but which have thumbnail data cached locally.
    # The latter type may be referenced by entities, e.g. for the logo of a site, or the profile picture of
    # a user, or the image associated with a recipe.
    # In this case, the type of reference being used is given by the :as option to linkable, viz :as => ImageReference
    #

    # options[:as]: the class which the referent keeps as an affiliate
    def linkable(url_attribute, reference_association, options = {})
      reference_association_pl = reference_association.to_s.pluralize.to_sym
      reference_association = reference_association.to_sym
      ref_type = options[:as] || "#{self.to_s}Reference"

      # The url attribute is accessible, but access is through an instance method that
      # defers to a Reference
      attr_accessible url_attribute, reference_association

      # Can get back to references this way:
      if options[:as]
        # References for ancillary attributes (e.g., thumbnails) belong to their affiliates
        belongs_to reference_association, class_name: ref_type
      else
        # References that define the location of their affiliates have a many-to-one relationship (i.e. many URLs can refer to the same entity)
        has_one reference_association, -> { where type: ref_type, canonical: true }, foreign_key: "affiliate_id", class_name: ref_type
        has_many reference_association_pl, -> { where type: ref_type }, foreign_key: "affiliate_id", class_name: ref_type, dependent: :nullify
      end

      self.class_eval do
        unless options[:as]
          # For the one attribute used to index the entity, provide access to its name for use in class and instance methods
          define_singleton_method :url_attribute_name do
            url_attribute
          end
=begin
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
              ref = Reference.find_or_initialize url, type: "#{self.to_s}Reference"
              obj = ref.affiliate || self.new(params)
              obj.method(:"#{reference_association}=").call ref
            end
            obj
          end

          define_singleton_method :find_or_create do |url, params={}|
            obj = self.find_or_initialize url, params
            obj.save unless obj.id || obj.errors.any?
            obj
          end
=end
        end
      end

      self.instance_eval do

        # Define singleton getter and setter methods for the URL by using a Reference object.
        # Once a URL is in use for an entity of a particular type (Recipe, site, image, etc.), it
        # remains bound to that entity until the entity is destroyed.
        # In particular, this gives a special meaning to url assignment: the URL is 1) checked that it
        #  is unique within the class (actually, type of Reference) and then 2) non-destructively assigned
        #  to the object by creating a new Reference bound to the object.
        # IT IS AN ERROR TO ASSIGN A URL WHICH IS IN USE BY ANOTHER ENTITY OF THE SAME CLASS.
        define_method "#{url_attribute}=" do |pu|
          # Since we can't modify references once created, we can only assert a new
          # URL by resort to a new reference
          # Get the existing reference
          if options[:as]
            # The reference is to another entity type: we just index by URL and assign the reference association
            self.method(:"#{reference_association}=").call (pu.blank? ? nil : ref_type.constantize.find_or_initialize(pu).first)
          elsif pu.blank?
            self.errors.add("#{url_attribute} can't be blank")
          else
            # Create a new reference (or references, if there's a redirect involved) as necessary
            refs = ref_type.constantize.find_or_initialize(pu)
            # Give me the new references
            self.method(:"#{reference_association}=").call refs.first
            self.method(:"#{reference_association_pl}=").call refs
          end
          if self.has_attribute? url_attribute
            # Set the old url attribute--if it still exists
            super pu
          end
          pu
        end

        define_method(url_attribute) do
          # This will cause an exception for entities without a corresponding reference
          ((reference = self.method(reference_association).call) && reference.url) ||
          (self.has_attribute?(url_attribute) && super())
        end

        unless options[:as]
          # The site for a referenced object
          define_method :site do
            @site ||= Site.find_or_create self.method(reference_association_pl).call.map(&:url)
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
    site.home
  end

end

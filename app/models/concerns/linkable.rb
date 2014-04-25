require './lib/uri_utils.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class
module Linkable
  extend ActiveSupport::Concern

  module ClassMethods

    # Make an attribute of the class linkable, i.e., it contains a URL which is unique to the class,
    # and which is supplanted by a Reference object, except in the case of the Reference class.
    # Options (the first two of which may be given positionally or by name in the options hash):
    # ref_attribute: a symbol for the attribute carrying a Reference object
    # ref_type: the type of Reference that is to contain (URLs are only unique within a type)
    # href_attribute: a secondary URL attribute which can be used to complete a primary URL (i.e., in
    #   the case of images, which may have a relative path)
    # site_from: specifies an attribute that can be used to look up the site associated with the URL
    #   (only matters for classes with multiple linkable attributes)

    # A linkable attribute isn't a key for the class, but DOES have a corresponding reference
    def linkable(url_attribute, href_attribute, ref_type, options = {} )
      if href_attribute.is_a? Hash
        options = href_attribute
        href_attribute = options[:href_attribute]
        ref_type = options[:ref_type]
      end
      self.class_eval do
        # Critical method to ensure no two linkables of the same class [offset] have the same link
        define_singleton_method :find_or_initialize do |params|
          # Normalize it
          url = params[url_attribute]
          href = params[href_attribute]
          obj = self.new params
          if url.blank? # Check for non-empty URL
            obj.errors.add url_attribute, "can't be blank"
          elsif !(normalized = normalize_and_test_url url, href)
            obj.errors.add url_attribute, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
          else
            urlspec = {url_attribute => normalized}
            obj.attributes = urlspec
            if extant = self.where(params.slice(:type).merge urlspec).first
              # Recipe already exists under this url
              obj = extant
            end
          end
          obj
        end
      end # class_eval

      attr_accessible url_attribute
      if options[:href_attribute] # This is a fallback attribute, a url for resolving partial paths
        attr_accessible options[:href_attribute]
      end
      belongs_to href_attribute, :class_name => "Reference", :conditions => "type = '#{ref_type}'" # has_one :link, :as => :entity
      accepts_nested_attributes_for href_attribute

      self.instance_eval do
        # Define singleton getter and setter methods for the reference
        define_method "#{url_attribute}=" do |pu|
          prior = self.method(url_attribute).call
          unless (pu || "") == (prior || "") # Compares correctly even if one is nil
            newref = pu.blank? ? nil : Reference.find_or_initialize(type: ref_type, url: pu)
            self.method("#{href_attribute}=").call newref
          end
          pu
        end

        define_method(url_attribute) do
          ref_obj = self.method(href_attribute).call
          ref_obj ? ref_obj.url : super()
        end
      end
    end

    # key_linkable refers to a url attribute that must be unique across the owning class.
    # The URL may or may not be defined by a corresponding Reference
    def key_linkable(url_attribute, href_attribute=nil, ref_type=nil, options = {} )
      if href_attribute.is_a? Hash
        options = href_attribute
        href_attribute = options[:href_attribute]
        ref_type = options[:ref_type]
      end
      self.class_eval do
        class_variable_set '@@url_attribute_name', nil
        class_variable_set '@@href_attribute_name', nil
        define_singleton_method :url_attribute_name do
          self.class_variable_get '@@url_attribute_name'
        end
        define_singleton_method :href_attribute_name do
          self.class_variable_get '@@href_attribute_name'
        end

        # Critical method to ensure no two linkables of the same class [offset] have the same link
        define_singleton_method :find_or_initialize do |params|
          # Normalize it
          url_attribute_name = self.url_attribute_name # self.class_variable_get '@@url_attribute_name'
          url = params[url_attribute_name]
          href_attribute_name = self.href_attribute_name # self.class_variable_get '@@href_attribute_name'
          href = params[href_attribute_name]
          obj = self.new params
          if url.blank? # Check for non-empty URL
            obj.errors.add url_attribute_name, "can't be blank"
          elsif !(normalized = normalize_and_test_url url, href)
            obj.errors.add url_attribute_name, "\'#{url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
          else
            urlspec = {url_attribute_name => normalized}
            obj.attributes = urlspec
            if extant = self.where(params.slice(:type).merge urlspec).first
              # Recipe already exists under this url
              obj = extant
            end
          end
          obj
        end
      end

      attr_accessible url_attribute
      self.class_variable_set '@@url_attribute_name', url_attribute unless self.class_variable_get '@@url_attribute_name'
      # self.url_attribute_name = url_attribute unless self.url_attribute_name  # Defaults to the first url_attribute named as linkable
      self.class_variable_set '@@url_attribute_name', options[:site_from] if options[:site_from] #...but can be forced thus

      if options[:href_attribute] # This is a fallback attribute, a url for resolving partial paths
        self.class_variable_set '@@href_attribute_name', options[:href_attribute]
        attr_accessible options[:href_attribute]
      end

      if href_attribute # Delegate URL access to a corresponding reference
        belongs_to href_attribute, :class_name => "Reference", :conditions => "type = '#{ref_type}'" # has_one :link, :as => :entity
        accepts_nested_attributes_for href_attribute

        self.instance_eval do
          # Define singleton getter and setter methods for the reference
          define_method "#{url_attribute}=" do |pu|
            prior = self.method(url_attribute).call
            unless (pu || "") == (prior || "") # Compares correctly even if one is nil
              newref = pu.blank? ? nil : Reference.find_or_initialize(type: ref_type, url: pu)
              self.method("#{href_attribute}=").call newref
            end
            pu
          end

          define_method(url_attribute) do
            ref_obj = self.method(href_attribute).call
            ref_obj ? ref_obj.url : super()
          end
        end
      end
    end # Linkable
  end # ClassMethods

  def self.included(base)
    base.extend(ClassMethods)
  end

  public

  def site
    return @site if @site
    primary_url = self.method(self.class.url_attribute_name).call
    unless @site = primary_url && Site.by_link(primary_url)
      secondary_url = self.class.href_attribute_name && self.method(self.class.href_attribute_name).call
      @site = secondary_url && Site.by_link(secondary_url)
    end
    @site
  end

  # Return the human-readable name for the recipe's source
  def sourcename
    site.name
  end

  # Return the URL for the recipe's source's home page
  def sourcehome
    site.home_page
  end

end

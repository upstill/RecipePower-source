require './lib/uri_utils.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class
module Linkable
  extend ActiveSupport::Concern

  module ClassMethods

    # If only the attribute is passed, this class has the field directly
    def linkable(attribute, ref_attribute=nil, ref_type=nil, href_attribute=nil)
      @@url_attrib_name = attribute
      @@ref_attrib_name = ref_attribute
      @@ref_type_name = ref_type
      @@href_attrib_name = href_attribute
      attr_accessible attribute
      attr_accessible(href_attribute) if href_attribute
      @@getter_method = @@setter_method = nil
      @@ref_getter_method = @@ref_setter_method = nil

      if ref_attribute
        belongs_to ref_attribute, :conditions => "type = '#{ref_type}'" # has_one :link, :as => :entity
        accepts_nested_attributes_for ref_attribute
      end

      define_method(@@url_attrib_name) do
        s = self.class.new
        if @@ref_attrib_name
          unless @@ref_getter_method
            debugger
            @@ref_getter_method = self.method @@ref_attrib_name
          end
          ref_obj = @@ref_getter_method.call
          ref_obj ? ref_obj.url : super()
        else
          super()
        end
      end

      define_method "#{@@url_attrib_name}=" do |pu|
        s = self.class.new
        unless @@getter_method
          @@getter_method = s.method @@url_attrib_name
        end
        prior = @@getter_method.call
        return pu if (pu || "") == (prior || "")  # Compares correctly even if one is nil
        if @@ref_attrib_name
          debugger
          unless @@ref_setter_method
            @@ref_setter_method = s.method "#{@@ref_attrib_name}="
          end
          newref = pu.blank? ? nil : Reference.find_or_initialize(type: @@ref_type_name, url: pu)
          @@ref_setter_method.call newref
        else
          super(pu) # Assume that the generic setter method applies, i.e., that the field exists explicitly
        end
        pu
      end

    end

    def url_attrib_name
      @@url_attrib_name
    end

    def href_attrib_name
      @@href_attrib_name
    end

    # Critical method to ensure no two linkables of the same class [offset] have the same link
    def find_or_initialize(params)
      # Normalize it
      obj = self.new params
      if params[url_attrib_name].blank?  # Check for non-empty URL
        obj.errors.add url_attrib_name, "can't be blank"
      elsif !(normalized = normalize_and_test_url(params[url_attrib_name], (params[href_attrib_name] if href_attrib_name)))
        obj.errors.add url_attrib_name, "\'#{params[url_attrib_name]}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
      elsif extant = self.where(params.slice(:type).merge(url_attrib_name => obj.private_url = normalized)).first
        # Recipe already exists under this url
        obj = extant
      end
      obj
    end

    def seek_on_url(url)
      (normalized = normalize_url(url)) && self.where(url_attrib_name => normalized).first
    end

  end

  self.instance_eval do
    debugger
    define_method "#{@@url_attrib_name}=" do |pu|
      s = self.class.new
      unless @@getter_method
        @@getter_method = s.method @@url_attrib_name
      end
      prior = @@getter_method.call
      return pu if (pu || "") == (prior || "")  # Compares correctly even if one is nil
      if @@ref_attrib_name
        debugger
        unless @@ref_setter_method
          @@ref_setter_method = s.method "#{@@ref_attrib_name}="
        end
        newref = pu.blank? ? nil : Reference.find_or_initialize(type: @@ref_type_name, url: pu)
        @@ref_setter_method.call newref
      else
        super(pu) # Assume that the generic setter method applies, i.e., that the field exists explicitly
      end
      pu
    end
  end

  # def InstanceMethods

  # end

  def self.included(base)
    base.extend(ClassMethods)
  end

  public

  def private_url
    self.read_attribute self.class.url_attrib_name
  end

  def private_url=(url)
    self.attributes = { self.class.url_attrib_name => url }
  end

  def private_href
    self.read_attribute( self.class.href_attrib_name) if self.class.href_attrib_name
  end

  def site
    @site ||= private_url && Site.by_link(private_url)
    @site ||= private_href && Site.by_link(private_href)
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

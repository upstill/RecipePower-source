require './lib/uri_utils.rb'

# Manage a URL associated with a model such that the URL is unique across the model's class
module Linkable
  extend ActiveSupport::Concern

  module ClassMethods

    def linkable(attribute, href_attribute=nil)
      @url_attrib_name = attribute
      @href_attrib_name = href_attribute
      attr_accessible attribute
      attr_accessible(href_attribute) if href_attribute
      validates_uniqueness_of attribute
    end

    def url_attrib_name
      @url_attrib_name
    end

    def href_attrib_name
      @href_attrib_name
    end

    # Critical method to ensure no two linkables of the same class [offset] have the same link
    def find_or_initialize(params)
      # Normalize it
      obj = self.new params
      if obj.private_url.blank?  # Check for non-empty URL
        obj.errors.add url_attrib_name, "can't be blank"
      elsif !(normalized = normalize_and_test_url(obj.private_url, (params[href_attrib_name] if href_attrib_name)))
        obj.errors.add url_attrib_name, "\'#{obj.private_url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
      elsif extant = self.where(params.slice(:type).merge(url_attrib_name => obj.private_url = normalized)).first
        # Recipe already exists under this url
        obj = extant
      end
      obj
    end
    
    def seek_on_url(url)
      (normalized = normalize_url(private_url)) && self.where(url_attrib_name => normalized).first
    end
    
  end
  
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

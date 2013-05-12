require './lib/uri_utils.rb'

module Linkable
  extend ActiveSupport::Concern
  
  included do
    attr_accessible :url

    validates_uniqueness_of :url
  end
  
  module ClassMethods
    
    # Critical method to ensure no two recipes have the same link
    def find_or_initialize(params)
      # Normalize it
      obj = self.new params
      if obj.url.blank?  # Check for non-empty URL
        obj.errors.add :url, "can't be blank"
      elsif !(normalized = normalize_and_test_url(obj.url, params[:href]))
        obj.errors.add :url, "\'#{obj.url}\' doesn't seem to be a working URL. Can you use it as an address in your browser?"
      elsif extant = self.where(url: obj.url = normalized).first
        # Recipe already exists under this url
        obj = extant
      end
      obj
    end
    
    def seek_on_url(url)
      (normalized = normalize_url(url)) && self.where(url: normalized).first
    end
    
  end
  
  def self.included(base)
    base.extend(ClassMethods)
  end 
  
  def site
    @site ||= Site.by_link(url) || (href && Site.by_link(href))
  end

  # Return the human-readable name for the recipe's source
  def sourcename
    # @site = @site || Site.by_link(self.url)
    # @site.name
    site.name
  end

  # Return the URL for the recipe's source's home page
  def sourcehome
    # @site = @site || Site.by_link(self.url)
    # @site.home
    site.home
  end

end
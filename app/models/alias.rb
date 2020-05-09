class Alias < ApplicationRecord
  belongs_to :page_ref
  
  validates_uniqueness_of :url

  # This is a url stripped of all redundant information:
  # -- protocol
  # -- trailing slash in the path
  # -- target
  # HOWEVER: the input url may come without any of those aspects
  def self.indexing_url url
    url = 'http://' + url unless url.match(/^https?:\/\//)
    url = PageRef.standardized_url url # Start by stripping the target from the URL, ala PageRef
    url = begin
            uri = URI(url) # Elide the fragment for purposes of finding
            pth = uri.path
            uri.path = pth[0..-2] if pth[-1] == '/' # Truncate to elide terminating '/'
            uri.to_s
          rescue
            url
          end
    url.sub /^https?:\/\//, '' # Finally, remove the protocol
  end

  def self.urleq url1, url2
    self.indexing_url(url1) == self.indexing_url(url2)
  end

  # Will this alias find this url?
  def will_map_to? url
    url == self.class.indexing_url(url)
  end

  # Use arel to generate a query (suitable for #where or #find_by) to match the url
  def self.url_query url
    # For purposes of indexing, we collapse certain aspects of urls:
    # -- remove the protocol and target
    # -- no lone slash for a path
    return self.arel_table[:url].eq self.indexing_url(url)
  end

  def self.find_by_url url
    self.find_by(self.url_query url)
  end

  # Use arel to generate a query (suitable for #where or #find_by) to match a subpath of the url
  # Input: the domain+path part of a URL, but any proper URL is handled, even if it includes
  # the protocol, a target, and a trailing '/' on the path
  # Since the path has neither protocol nor target, we only need to include the '%' wildcard at the end
  def self.url_path_query urlpath
    self.arel_table[:url].matches self.indexing_url(urlpath)+'%'
  end
  
  # We only allow urls in their reduced form for indexing purposes
  def url= url
    super self.class.indexing_url(url)
  end
end

class Alias < ApplicationRecord
  belongs_to :page_ref

  # This is a url stripped of all redundant information:
  # -- target
  # -- trailing slash
  # -- protocol
  def self.reduced_url url
    indexing_url(url).sub /^https?:\/\//, ''
  end

  # Use arel to generate a query (suitable for #where or #find_by) to match the url
  def self.url_query url
    # For purposes of indexing, we collapse certain aspects of urls:
    # -- remove the protocol and target
    # -- no lone slash for a path
    return self.arel_table[:url].eq self.reduced_url(url)
  end

  # Use arel to generate a query (suitable for #where or #find_by) to match a subpath of the url
  # Input: the domain+path part of a URL, optionally including the prefatory 'http://'
  # We supply the protocal as necessary for the benefit of #reduced_url
  # Since the path has neither protocol nor target, we only need to include the '%' wildcard at the end
  def self.url_path_query urlpath
    urlpath = 'http://'+urlpath unless urlpath.match(/^http/)
    self.arel_table[:url].matches self.reduced_url(urlpath)+'%'
  end
  
  # We only allow urls in their reduced form for indexing purposes
  def url= url
    super self.class.reduced_url(url)
  end
end

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

  # Use arel to generate a query (suitable for #where or #find_by) to match the url path
  # Since the path has neither protocol nor target, we only need to include the '%' wildcard at the end
  def self.url_path_query urlpath
    self.arel_table[:url].matches urlpath.sub(/\/?$/, '%')
  end

  # We only allow urls in their reduced form for indexing purposes
  def url= url
    super self.class.reduced_url(url)
  end
end

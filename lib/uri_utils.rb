require 'uri'
require 'open-uri'
require 'nokogiri'

def validate_link link
  link =~ URI::regexp(%w{ http https data })
end

# Try to make sense out of a given path in the context of another url.
# Return either a valid URL or nil
def valid_url(url, path=nil)
  path ||= ""
  if validate_link(path) && good = test_link(path) # either the original URL or a replacement are good
    return (good.class == String) ? good : path
  elsif url
    # The path may be relative. In fact, it may have backup characters
    begin
      uri = URI.join( url, path ).to_s
      return validate_link(uri) && uri
    rescue Exception => e
      return nil
    end
  end
end

# Probe a URL with its server, returning the result code for a head request
def header_result(link, resource=nil)
  begin
    url = resource ? URI.join(link, resource) : URI.parse(link)
    # Reject it right off the bat if the url isn't valid
    return 400 unless url.host && url.port

    req = Net::HTTP.new(url.host, url.port)
    code = req.request_head(url.path).code
    (code == "301") ? req.request_head(url.path).header["location"] : code.to_i
  rescue Exception => e
    # If the server doesn't want to talk, we assume that the URL is okay, at least
    return 401 if e.kind_of?(Errno::ECONNRESET) || url
  end
end

def safe_parse(url)
  begin
    URI.parse(url) if url
  rescue Exception => e
    return nil
  end
end

def normalize_url(url)
  (uri = safe_parse(url)) && uri.normalize.to_s
end

def normalize_and_test_url(url, href=nil)
  return nil unless normalized = normalize_url(url)
  if !(valid_url = test_link(normalized))
    # Try to construct a valid url by merging the href and the url
    if (uri = safe_parse(href)) && (normalized = uri.normalize.merge(normalized).to_s)
      valid_url = test_link normalized
    end
  end
  ((valid_url.kind_of? String) ? valid_url : normalized) if valid_url
end

# Confirm that a proposed URL (with an optional subpath) actually has content at the other end
# If the link is badly formed (returns a 400 result from the server) then we return false
# If the resource has moved (result 301) and the new location works, we return the new link
# Otherwise, we just return true. 
# Thus: false means fail; string means good but moved; true means the link is valid as specified
def test_link(link, resource=nil)
  # If the result method can't make sense of the link, then give up
  return false unless result_code = header_result(link, resource)
  # Not very stringent: we only disallow ill-formed requests
  return (result_code != 400) unless result_code.kind_of? String
  
  # If the location has moved permanently (result 301) we try to supplant this link internally
  if (new_location = result_code) && (header_result(new_location) == 200)
    new_location
  else
    true
  end
end

 # Return a list of image URLs for a given page
def page_piclist(url)
  begin 
    return [] unless (ou = open url) && (doc = Nokogiri::HTML(ou))
  rescue Exception => e
    return []
  end
  # Get all the img tags, uniqify them, purge non-compliant ones and insert the domain as required
  doc.css("img").map { |img| 
    img.attributes["src"] # Collect all the "src" attributes from <img tags
  }.compact.map { |src| # Ignore if nil
    src.value # Extract value (URL string)
  }.uniq. # Purge duplicates
  # keep_if { |url| url =~ /\.(gif|tif|tiff|png|jpg|jpeg|img)$/i }. # Accept only image tags (NB: apparently irrelevant)
  map{ |path| 
    begin
      (uri = URI.join( url, path)) && uri.to_s 
    rescue Exception => e
      nil
    end 
  }.compact
end

# Ensure that a hash of query parameters makes it into the given url
def assert_query url, newparams={}
  return url if newparams.empty?
  uri = URI(url)
  qparams = uri.query.blank? ? { } : CGI::parse(uri.query)
	newparams.each { |k, v| qparams[k.to_s] = [ v.to_s ] } # Assert the new params, poss. over the old
  uri.query = qparams.collect { |k, v| "#{k.to_s}=#{CGI::escape v[0]}" unless v.empty? }.compact.join('&')
  uri.to_s
end

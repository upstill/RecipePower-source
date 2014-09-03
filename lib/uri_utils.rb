require 'uri'
require 'open-uri'
require 'nokogiri'

def validate_link link
  link =~ URI::regexp(%w{ http https data })
end

# Try to make sense out of a given path in the context of another url.
# Return either a valid URL or nil
def valid_url(path, url)
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
    partial = url.path + ((query = url.query) ? "?#{query}" : "")
    code = req.request_head(partial).code.to_i
    # Redirection codes
    [301, 302].include?(code) ? req.request_head(partial).header["location"] : code
  rescue Exception => e
    # If the server doesn't want to talk, we assume that the URL is okay, at least
    return 401 if e.kind_of?(Errno::ECONNRESET) || url
  end
end

def safe_parse(url)
  begin
    uri = url && URI.parse(url)
  rescue Exception => e
    uri = nil
  end

  if url && !uri  # Failed with exception => Try to fix the fragment, which may have bad characters
    spl = url.split('#')
    if (spl.size > 1) && ((refrag = URI::encode(spl[-1])) != spl[-1])
      begin
        spl[-1] = refrag
        uri = URI.parse spl.join('#')
      rescue Exception => e
        uri = nil
      end
    end
  end
  uri
end

# Since URI can't handle diacriticals in the fragment, encode them
def fix_fragment url
  spl = url.split('#')
  if spl.size > 1
    spl[-1] = URI::encode(spl[-1])
    spl.join('#')
  else
    url
  end
end

def sanitize_url url
  url.strip.gsub(/\{/, '%7B').gsub(/\}/, '%7D').gsub(/\%23/, '#' )
end

# Return nil if anything is amiss, including nil or empty url
def normalize_url url
  ((uri = safe_parse(sanitize_url url)) && uri.normalize.to_s) unless url.blank?
end

# Parse the url and return the protocol, host and port portion
def host_url url
  if (uri = safe_parse(sanitize_url url)) && !uri.host.blank?
    uri.path = ""
    uri.query = uri.fragment = nil
    uri.normalize.to_s
  end
end

# Test that a (previously normalized) url works, possibly relative to a secondary href.
def test_url normalized, href=nil
  if !(valid_url = test_link(normalized) ||
      ((normalized =~ /^https/) && test_link(normalized.sub! /^https/, 'http')))
    # Try to construct a valid normalized by merging the href and the url
    if (uri = safe_parse(href)) && (normalized = uri.normalize.merge(normalized).to_s)
      valid_url = test_link(normalized) ||
          ((normalized =~ /^https/) && test_link(normalized.sub! /^https/, 'http'))
    end
  end
  ((valid_url.kind_of? String) ? valid_url : normalized) if valid_url
end

def normalize_and_test_url(url, href=nil)
  return nil unless normalized = normalize_url(url)
  test_url normalized, href
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
def page_piclist url
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

# Inverse of CGI.parse: take a hash of key/array-of-value pairs and produce a query string
# NB: THIS ESCAPES EVERYTHING, SO THIS IS NOT A STRICT INVERSE, I.E., IT IS LIKELY TO PRODUCE A DIFFERENT QUERY STRING
def build_query(params)
  params.map do |name,values|
    values.map do |value|
      "#{CGI.escape name}=#{CGI.escape value}"
    end
  end.flatten.join("&")
end

# Ensure that a hash of query parameters makes it into the given url. A format may also be asserted
def assert_query url, format=nil, newparams={}
  if format.is_a? Hash
    newparams, format = format, nil
  end
  return url if newparams.empty? && (format.blank? || format=="html")
  uri = URI(url)
  if format
    # Assert the format by stripping any terminating format string and appending the one specified
    trunc = uri.path.sub /\.(json|ps|html)$/, ''
    uri.path = trunc + '.' + format
  end
  qparams = uri.query.blank? ? { } : CGI::parse(uri.query)
	newparams.each { |k, v|
    if v
      qparams[k.to_s] = [ v.to_s ]
    else
      qparams.delete k.to_s
    end
  } # Assert the new params, poss. over the old
  newq = qparams.collect { |k, v| "#{k.to_s}=#{CGI::escape v[0]}" unless v.empty? }.compact.join('&')
  uri.query = newq.blank? ? nil : newq
  uri.to_s
end

# Generate a hashtag which triggers a modal dialog
def hash_to_modal url, base_path=nil
  base_path ||= "/collection"
  uri = URI.parse(url)
  index = url.index uri.path
  relative_url = assert_query(url[index..-1], :modal => true)
  "#{base_path}#dialog:#{CGI::escape relative_url}"
end

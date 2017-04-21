require 'uri'
require 'open-uri'
require 'nokogiri'

def validate_link link, protocols=nil
  if link.present?
    protocols ||= %w{ http https data }
    link =~ /\A#{URI::regexp(protocols)}\z/
  end
end

# Try to make sense out of a given path in the context of another url.
# Return either a valid URL or nil
def valid_url path, url
  path ||= ""  # Could happen
  if validate_link(path) && good = test_link(path) # either the original URL or a replacement are good
    return (good.class == String) ? good : path
  elsif url
    # The path may be relative. In fact, it may have backup characters
    begin
      uri = URI.join( url, path ).to_s
      uri if validate_link(uri)
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
    req.use_ssl = (url.scheme == "https")
    partial = url.path + ((query = url.query) ? "?#{query}" : "")
    head = req.request_head(partial)
    code = head.code.to_i rescue 400
    # Redirection codes
    redirect = head.header["location"] if [301, 302, 303].include?(code)
    redirect.present? ? redirect : code
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
  uri.scheme = 'http' if uri && uri.scheme.present?
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

# Fix errant characters without re-escaping '%'
def sanitize_url url
  URI.encode(url).gsub(/\%23/, '#' ).gsub(/\%25/, '%' ) if url

=begin
  url.strip.
      gsub(/\{/, '%7B').
      gsub(/\}/, '%7D').
      gsub(/ /, '%20').
      gsub(/\%23/, '#' )
=end
end

# Return nil if anything is amiss, including nil or empty url
def normalized_uri url
  if url.present? && (sp = sanitize_url url) && (uri = safe_parse(sp))
    uri.normalize!
    uri
  end
end

def normalize_url url
  if (uri = normalized_uri(url)) && uri.host.present?
    uri.to_s
  end
end

# Map url or urls into their normalized form, optionally removing the protocol
# 'http://ganga.com' -> ['http://ganga.com']
# 'http://ganga.com', true -> ['ganga.com']
# (see test/unit/uri_utils_test.rb for full test suite)
def normalize_urls url_or_urls, strip_protocol=false
  (url_or_urls.is_a?(Array) ? url_or_urls : [url_or_urls]).map { |url|
    if (norm = normalize_url(url)) && strip_protocol
      norm.sub!(/^(http[^\/]*)?\/\//, '')
    end
    norm if norm.present?
  }.compact.uniq
end

# Parse the url and return the protocol, host and port portion
def host_url url
  if (uri = safe_parse(sanitize_url url)) && !uri.host.blank?
    uri.path = ''
    uri.query = uri.fragment = nil
    uri.normalize.to_s.sub(/\/$/,'') # Remove trailing slash from normalized form
  end
end

# string -> string
# If the URL is valid, return only its path, including domain
# Examples:
# http://jibit.com => jibit.com
# http://jibit.com/ => jibit.com
# http://jibit.com/a?x=2#anchor => jibit.com/a
def cleanpath url
  if (uri = safe_parse(sanitize_url url)) && uri.host.present?
    path = uri.path.sub(/\/$/,'').sub(/^\//, '') # Remove trailing slash from normalized form
    base = uri.host.sub(/\/$/,'')
    path.present? ? "#{base}/#{path}" : base
  end
end

# string -> Array of strings
# Turn a url into a set of strings, each beginning with the host domain, with one
# string for every subpath of the original url. The purpose is to enable searching
# sites by subpath
# Examples: (see also test/uri_utils_test.rb)
def subpaths url
  return [] if url.blank?
  if path = cleanpath(url)
    dirs = path.split '/'
    base = dirs.shift # Get the host
    dirs.inject([base]) { |result, dir|
      result << result.last + '/' + dir
    }
  end
end

# Test that a (previously normalized) url works, possibly relative to a secondary href.
def test_url normalized, href=nil
  insecure = normalized.sub /^https:/, 'http:'
  secure = insecure.sub /^http:/, 'https:'
  if !(valid_url = test_link(insecure) || test_link(secure))
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
  format = format.to_s
  return url if newparams.empty? && (format.blank? || format=="html")
  uri = URI(url)
  unless format.blank?
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

# Crack a query string into a key/value hash
# TODO: only handles top-level keys; should be supplying a subhash for nested keys
def query_to_hash qstr
  result = {}
  qstr.split('&').each { |assign|
    key, val = assign.split('=')
    result[key.to_sym] = val
  }
  result
end

# Break a request into path and query components.
# Return a hash whose :path member is the path and :query is the query hash
# 'imposed_query' may be specified to modify the query
def analyze_request url, imposed_query={}
  uri = URI(url)
  qparams = (uri.query.blank? ? { } : CGI::parse(uri.query))
  uri.query = nil
  path = uri.to_s
  { path: path, query: qparams.merge(imposed_query) }
end

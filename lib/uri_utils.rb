require 'uri'

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

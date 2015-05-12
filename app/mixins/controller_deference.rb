# Mixin for application controller to provide for pushing and popping requests
module ControllerDeference

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def defer_request spec={}
    DeferredRequest.push rp_uuid, unpack_path(spec) # pack_request(spec)
  end

  # Recall an earlier, deferred, request that can be redirected to in the current context .
  # This isn't as easy as it sounds: if the prior request was for a format different than the current one,
  #  we have to redirect to a request that will serve this one, as follows:
  # -- if the current request is for JSON and the earlier one was for a page, we send back JSON instructing that page load
  # -- if the current request is for a page and the earlier one was for JSON, we can send back a page that spring-loads
  #!  the JSON request
  def deferred_request specs=nil
    # The input specs denote a default path that CAN help with this one, but may be replaced from deferred requests
    requested = unpack_path path: request.fullpath, format: request.format.symbol
    if pending = request_matching(requested.slice(:format))
      defer_request specs if specs
      return pending
    end
    if specs
      needed = unpack_path specs  # Derive format and mode from the 'needed' spec, if not already specified
      out_path = pack_path needed  # Put the derived specs back into the path
      # Now we just find a way to answer the request with the provided request
      case requested[:format]
        when needed[:format] # && requested[:format] == needed[:format]
          # The provided spec will do nicely, thank you
          out_path
        when :html
          # Need a page but it's not a page
          page_with_trigger out_path
        when :json
          # Need JSON but not JSON
          goto_url to: %Q{"#{out_path}"} # the redirect#go JSON response will get the client to request page
        else
          x=2
      end
    end
  end

  # If there's a deferred request that can be expressed as a trigger, do so.
  def pending_modal_trigger
    # A modal dialog has been embedded in the USL as the trigger param
    if req = response_service.trigger || current_user &&
        (request_matching(:format => :json, :mode => :modal) ||
        request_matching(:format => :json, :mode => :injector))
      assert_query req, mode: :modal
    end
  end

  private

  # Get a spec from deferred requests that matches the format and mode, if any
  def specs_matching specs
    (req = DeferredRequest.pull( rp_uuid, specs)) && unpack_request(req)
  end

  # If there is a deferred request, fetch it as a spec and return it as a request path
  def request_matching specs
    (specs = specs_matching specs) && (pack_path specs)
  end

  # Restore a deferred request after deserialization
  def unpack_request dr
    if dr
      # dr[:path] = URI::encode(dr[:path])
      dr[:format] = dr[:format].to_sym if dr[:format]
      dr
    end
  end

  # For a spec hash which includes :path, :format, and :mode, strip the path, defining :format and :mode if not defined already
  def unpack_path specs
    # specs can be either a url string or hash
    unpacked = specs.is_a?(String) ? { path: specs } : specs.clone
    return unpacked if unpacked[:path].blank? # Nothing to see here

    uri = URI unpacked[:path]

    # Attend to the format as necessary
    unpacked[:format] ||= (format_match = uri.path.match(/\.([^.]*)$/)) ? format_match[1].to_sym : :html
    # Elide the format
    uri.path.sub! /\.[^.]*$/, ''

    # Attend to the mode (in the query)
    if uri.query && mode_match = uri.query.match(/mode=([^&]*)(\&?)/)
      unpacked[:mode] ||= mode_match[1].to_sym
      # Elide the mode declaration from the query
      uri.query.sub! /mode=[^&]*\&?/, ''
      uri.query.sub! /\&$/, '' # Remove ampersand that may have been left behind
      uri.query = nil if uri.query.blank?
    else
      unpacked[:mode] ||= :modal unless unpacked[:format] == :html
    end

    unpacked[:path] = uri.to_s
    unpacked
  end

  # For a spec hash as above, incorporate the :format and :mode constraints into the returned path
  def pack_path specs
    if path = specs[:path]
      uri = URI path
      if specs[:format] && (specs[:format] != :html)
        uri.path = uri.path + ".#{specs[:format]}"
      end
      if specs[:mode]
        mode = "mode=#{specs[:mode]}"
        uri.query = uri.query.blank? ? mode : "#{mode}&#{uri.query}"
      end
      uri.to_s
    end
  end
  
end

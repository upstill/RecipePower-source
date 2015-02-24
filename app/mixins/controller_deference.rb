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
  def deferred_request specs={}
    # The input specs denote a default path that CAN help with this one, but may be replaced from deferred requests
    needed = unpack_path specs # Derive format and mode from the 'needed' spec, if not already specified
    requested = unpack_path path: request.fullpath, format: request.format.symbol
    if pending = request_matching( requested.slice(:format) )
      defer_request needed
      return pending # needed[:path] = pending[:path]
    end
=begin
    # If there's a way to serve a deferred request directly, go for it
    # The provided specs don't match the request
    synthesized =
        case requested[:mode]
          # What are we looking for here?
          when :injector
            # Merrily assuming that a deferred :injector request is modal
            request_matching :mode => :injector
          when :page
            case needed[:mode]
              when :injector, :modal
                page_with_trigger request_matching(:mode => :page), pack_path(needed)
              when :partial
                needed[:mode] = :page # A partial has a whole-page version
                page = pack_path needed
                (dialog = request_matching(:mode => :modal)) ? page_with_trigger(page, dialog) : page
            end
          when :partial # Doesn't really apply
          when :modal
            # We're looking for a modal, and the provided specs don't match
            request_matching :mode => :modal
        end
    return synthesized if synthesized
    # Failed to reconcile the waiting requests with the provided spec, so if the provided spec suits, return it
=end
    out_path = pack_path needed
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

=begin
  # Take a url and return a version of that url that's good for a redirect, given
  #  that the redirect will have the format, method and mode of the current request.
  # options[:format] may be used to assert a format different from the current request
  #  (for expressing a preference upon deferral)
  # If not deferred (options[:deferred]), couch the url in an appropriate forwarding request for immediate response.
  def reconcile_request url, options={}
    options[:format] ||=  response_service.format
    options[:mode] = (options[:mode] || response_service.mode).to_sym

    target_format = (options[:format]).to_s
    uri = URI url
    if format_match = uri.path.match(/\.([^.]*)$/)
      source_format = format_match[1]
    end
    source_format = "html" if source_format.blank?

    target_mode = options[:mode]
    source_mode = query_to_hash(uri.query)[:mode].to_sym
    if (source_mode==:injector) != (target_mode==:injector)
      # If we're crossing between the injector context and the local context,
      # reject this request UNLESS we can convert it to a local modal
      if source_mode == :injector && target_mode == :modal
        # We're in a modal context, dealing with an injector request => convert from injector to modal
        uri.query = uri.query.sub(/mode=injector/, 'mode=modal')
        source_mode = :modal
        url = uri.to_s
      else
        return nil
      end
    end
    if (page_url = options[:in_page]) && (source_mode == :modal)
      url = view_context.page_with_trigger page_url, url
      source_mode = :page
      source_format = "html"
    end
    if source_format == target_format
      url
    elsif options[:deferred] # Return a redirecting url for in the stipulated format
      # Not immediate => we just make the request consistent with the desired format.
      # Presumably it will be saved as a deferred request and reconciled to the format under which it is restored.
      uri.path = uri.path.sub(/\.[^.]*$/, '') + ".#{target_format}"
      uri.to_s
    elsif target_format == "json"
      goto_url(to: %Q{"#{url}"}) # the redirect#go JSON response will get the client to request page
    else
      # Send them to a page that contains a trigger for the JSON
      # It will be either the current user's collection page or the home page (if no-one logged in)
      view_context.page_with_trigger root_path, url
    end
  end

  # Prepare a deferred request for serialization
  def pack_request specs={}
    specs[:mode] = (specs[:mode] || response_service.mode).to_sym
    specs[:format] ||= response_service.format
    specs[:path] ||= request.fullpath
    # Ensure that the saved request reflects the current mode and (over-rideable) format
    specs[:path] = assert_query specs[:path], specs.slice(:mode)
    specs[:path] = reconcile_request specs[:path], specs.merge( deferred: true ) # Don't embed it in a forwarding reference
    specs
  end
=end

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
      unpacked[:mode] ||= (unpacked[:format] == :html ? :page : :modal)
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
      if specs[:mode] && (specs[:mode] != :page)
        mode = "mode=#{specs[:mode]}"
        uri.query = uri.query.blank? ? mode : "#{mode}&#{uri.query}"
      end
      uri.to_s
    end
  end
  
end

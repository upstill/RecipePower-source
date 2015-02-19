# Mixin for application controller to provide for pushing and popping requests
module ControllerDeference

  # Recall an earlier, deferred, request that can be redirected to in the current context .
  # This isn't as easy as it sounds: if the prior request was for a format different than the current one,
  #  we have to redirect to a request that will serve this one, as follows:
  # -- if the current request is for JSON and the earlier one was for a page, we send back JSON instructing that page load
  # -- if the current request is for a page and the earlier one was for JSON, we can send back a page that spring-loads
  #!  the JSON request
  def deferred_request reconcile=true
    if df = pending_request
      # We can defer the reconciliation till later (see usage hereabouts)
      clear_pending_request if ready = reconcile ? reconcile_request(df[:fullpath]) : df[:fullpath]
      ready
    end
  end

  def query_to_hash qstr
    result = {}
    qstr.split('&').each { |assign|
      key, val = assign.split('=')
      result[key.to_sym] = val
    }
    result
  end

  # Take a url and return a version of that url that's good for a redirect, given
  #  that the redirect will have the format, method and mode of the current request.
  # options[:target_format] may be used to assert a format different from the current request
  #  (for expressing a preference upon deferral)
  # If not deferred (options[:deferred]), couch the url in an appropriate forwarding request for immediate response.
  def reconcile_request url, options={}
    target_format = (options[:target_format] || response_service.format).to_s
    uri = URI url
    if format_match = uri.path.match(/\.([^.]*)$/)
      source_format = format_match[1]
    end
    source_format = "html" if source_format.blank?

    target_mode = response_service.mode.to_sym
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

  # If there's a deferred request that can be expressed as a trigger, do so.
  def pending_modal_trigger
     # A modal dialog has been embedded in the USL as the trigger param
    assert_query(response_service.trigger, mode: :modal) if response_service.trigger
  end

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def defer_request format=nil
    DeferredRequest.push session.id, pack_request(request.fullpath, format)
  end

  def clear_pending_request
    DeferredRequest.pop session.id
  end

  # Get the currently-pending deferred request, fixing it for the current mode
  def pending_request
    unpack_request DeferredRequest.pending(session.id)
  end

  # Prepare a deferred request for serialization
  def pack_request path, format=nil
    # Ensure that the saved request reflects the current mode and (over-rideable) format
    path = assert_query path, :mode => response_service.mode
    reconciliation_options = { deferred: true }
    reconciliation_options[:target_format] = format if format
    path = reconcile_request path, reconciliation_options # Don't embed it in a forwarding reference
    { fullpath: URI::decode(path), format: (format || response_service.format) }
  end

  # Restore a deferred request after deserialization
  def unpack_request dr
    if dr
      dr[:fullpath] = URI::encode(dr[:fullpath])
      dr[:format] = dr[:format].to_sym if dr[:format]
      dr
    end
  end

end

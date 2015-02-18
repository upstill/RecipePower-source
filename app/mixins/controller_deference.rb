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
      clear_pending_request
      # We can defer the reconciliation till later (see usage hereabouts)
      reconcile ? (reconcile_format df[:fullpath], response_service.format) : df[:fullpath]
    end
  end

  # Take a url and return a version of that url that's good for a redirect, given
  #  that the redirect will have the format, method and mode of the current request.
  # 'target_format' may be used to assert a format different from the current request
  #  (for expressing a preference upon deferral)
  # If 'immediate' is true, couch the url in an appropriate forwarding request.
  def reconcile_format url, target_format=nil, immediate=true
    if target_format == true || target_format == false
      immediate, target_format = target_format, nil
    end
    target_format = (target_format || response_service.format).to_s
    uri = URI url
    if format_match = uri.path.match(/\.([^.]*)$/)
      source_format = format_match[1]
    end
    source_format = "html" if source_format.blank?
    return url if source_format == target_format
    if immediate
      if target_format == "json"
        goto_url(to: %Q{"#{url}"})  # the redirect#go JSON response will provide for getting the page
      else
        view_context.page_with_trigger root_path, url # Send them to either the current user's collection page or the home page (if no-one logged in)
      end
    else
      # Not immediate => we just make the request consistent with the desired format
      uri.path = uri.path.sub(/\.[^.]*$/, '') + ".#{target_format}"
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
    path = reconcile_format path, format, false # Don't embed it in a forwarding reference
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

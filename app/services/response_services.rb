# Class to govern production of pages and dialogs depending on context and params
# Contexts:
# => injector
# => mobile
# => desktop
# Format:
# => page
# => modal (iff param[:modal] == true)


class ResponseServices

  attr_accessor :action, :title

  def initialize params, session, request
    @request = request
    @session = session
    @response = params[:response]
    @controller = params[:controller]
    @title = @controller.capitalize
    @action = params[:action]
    @invitation_token = params[:invitation_token]
    @notification_token = params[:notification_token]
    # @area = params[:area]
    # @layout = params[:layout]
    # @partial = !params[:partial].blank?

    # Target is one of "desktop", "mobile" and "injector"
    @target = (params[:target] || "desktop") unless @session[:mobile]

    # Format dictates CSS style for the content (though not verbatim): within a dialog, or on a page
    # @format = (params[:format] || "page")
    # @format = "dialog" if (params[:how] == "modal")
    @modal = params[:modal]
  end

  # Provide a URL that reproduces the current request
  def originator
    @request.url
  end

  def omniauth_pending clear = false
    @session.delete(:omniauth) if clear
    @session[:omniauth] && @session[:omniauth][:provider]
  end

  # Change the response parameters to accommodate another URL, e.g. one that came in via omniauth
  def amend origin_url
    origin_url.sub! /^"?([^"]*)"?/, '\\1'  # Remove any enclosing quotes
    query_str = (match = origin_url.match /^[^?]*\?(.*)/ ) ? match[1] : ""
    query_params = query_str.empty? ? {} : Hash[ CGI.parse(query_str).map { |elmt| [elmt.first.to_sym, elmt.last.first] } ]
    @target = query_params[:target] if query_params[:target] unless @session[:mobile]
    # Format refers to how to present the content: within a dialog, or on a page
    @modal = query_params[:modal]
    # @format = "dialog" if query_params[:how] && (query_params[:how] == "modal")
  end
  
  def is_dialog set=true
    @modal = set
  end
  
  def dialog?
    !@modal.nil?
  end
  
  def is_injector
    @target = "injector"
  end
  
  # Returns true if we're in the context of a foreign page
  def injector?
    @target == "injector"
  end
  
  # True if we are to render a whole page
  def page?
    @modal.nil? # @format == "page"
  end
  
  def is_mobile(on=true)
    if on
      @session[:mobile] = true
      @target = nil
    else
      @session.delete :mobile
      @target = "desktop"
    end
  end
  
  # True if we're targetting mobile
  def mobile?
    @session[:mobile] && true
  end
  
  # Return relevant options for modal dialog
  def modal_options options_in = {}
    klass = (options_in[:class] || "") # +" modal-yield"
    options_in.merge class: klass
  end
  
  # Forward the appropriate parameters to a subsequent request
  def redirect_params options = {}
    options[:target] = @target # "injector" if injector?
    options[:modal] = @modal # options[:how] = "modal" if dialog?
    options
  end

  # Modify a path to match the current request, asserting other options as provided
  def decorate_path path, options={}
    assert_query path, redirect_params( options )
  end

  # What's the appropriate layout (in the Rails sense) for the current context?
  def layout
    case
      when injector?
        "injector"
      when page?
        "application"
      when mobile?
        "jqm"
      else
        false
    end
  end

  # Return the class specifier for styling according to the target
  def format_class
    case
      when injector?
        "injector"
      when dialog?
        "floating"
      when mobile?
        "mobile"
      else
        "page"
    end
  end

  # Return appropriate parameters for a render call, asserting defaults as necessary
  def render_params defaults = {}
    defaults.merge target: @target, layout: layout
  end

  # Recall an earlier, deferred, request that can be redirected to in the current context .
  # This isn't as easy as it sounds: if the prior request was for a format different than the current one,
  #  we have to redirect to a request that will serve this one, as follows:
  # -- if the current request is for JSON and the earlier one was for a page, we send back JSON instructing that page load
  # -- if the current request is for a page and the earlier one was for JSON, we can send back a page that spring-loads
  #!  the JSON request
  def deferred_request
    request =
    if df = pending_request
      if df[:format] == @request.format.symbol
        # We can handle this request directly because its format agrees with the current request
        clear_pending_request # Clear the pending request
        df[:fullpath]
      elsif df[:format] == :html
        clear_pending_request
        assert_query "/redirect/go", to: df[:fullpath]
      end
    end
    request
  end

  # Take a url and return a version of that url that's good for a redirect, given
  #  that the redirect will have the format and method of the current request. The
  #  options are used to assert a specific format, possibly different from the current one
  def url_for_redirect url, options={}
    if (!options[:format]) || (options[:format].to_sym == @request.format.symbol)  # They already match
      url
    else
      assert_query "/redirect/go", to: url
    end
  end

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def defer_request elements={}
    dr = {
        format: @request.format.symbol,
        fullpath: URI::decode(@request.fullpath)
    }.merge elements
    dr[:format] = dr[:format].to_s
    # str = YAML::dump dr
    if dri = @session[:deferred_requests_id]
      defreq = DeferredRequest.find dri
      (defreq.requests << str).uniq!
      defreq.save
    else
      @session[:deferred_requests_id] = DeferredRequest.create(:requests => [ dr ]).id
    end
    # @session[:deferred_request] = str
    dr
  end

  # If there's a deferred request that can be expressed as a trigger, do so.
  def pending_modal_trigger
    trigger =
    if  (dr = pending_request) &&
        (dr[:format] == :json) &&
        (!dr[:controller] || dr[:controller] == @controller) &&
        (!dr[:layout] || dr[:layout] == layout)
      clear_pending_request # Delete it 'cause we're using it
      dr[:fullpath]
    end
    trigger
  end

  # The signup button on the home page responds differently (and may or may not be a trigger)
  #  depending on the presence of an invitation token or a notification token in the params
  def signup_button_options
    options = { class: "btn btn-lg btn-success" }
    if @invitation_token
      # We've invited a new user, with or without a recipe share
      user = User.find_by_invitation_token(@invitation_token, false)
      notifications = user.notifications_received.where(accepted: false)
      options[:label] = notifications.empty? ? "Accept Invitation" : "Take Share"
      options[:class] << " trigger"
      options[:path] = Rails.application.routes.url_helpers.accept_user_invitation_path(invitation_token: @invitation_token)
    elsif @notification_token
      user = Notification.find_by_notification_token(@notification_token).target
      options[:label] = "Take Share"
      options[:path] = Rails.application.routes.url_helpers.new_user_session_path(user: {id: user.id, username: user.username})
      options[:class] << " trigger"
    else
      options[:label] = "Sign Me Up"
      options[:selector] = "div.dialog.signup"
      options[:path] = Rails.application.routes.url_helpers.new_user_registration_path()
    end
    options
  end

  # Used in templates for standard actions (e.g., new, edit, show) to choose a partial depending on
  # whether the response is for the injector, a modal dialog, or a page
  def select_render action=nil
    # defaults to current action, though another may be specified, even a full path
    "#{action || @action}_"+
        case
          when injector?
            "injector"
          when dialog?
            "modal"
          else
            "page"
        end
  end

  def container_selector
    if dialog?
      "div.dialog"
    else
      "div.container"
    end
  end

  private

  def clear_pending_request
    # @session.delete :deferred_request
    if (dri = @session[:deferred_requests_id]) && (defreq = DeferredRequest.where(id: dri).first)
      defreq.requests.pop
      if defreq.requests.empty?
        defreq.destroy
        @session.delete :deferred_requests_id
      else
        defreq.save
      end
    end
  end

  def pending_request
    # if dr = @session[:deferred_request]
    if (dri = @session[:deferred_requests_id]) &&
       (defreq = DeferredRequest.where(id: dri).first) &&
       (dr = defreq.requests[-1])
      # dr = YAML::load dr
      # Ensure that the target of the deferred request agrees with that of the present request
      dr[:fullpath] = assert_query URI::encode( dr[:fullpath]), :target => ('injector' if injector?)
      dr[:format] = dr[:format].to_sym
      dr
    end
  end
end

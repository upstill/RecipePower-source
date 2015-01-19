# Class to govern production of pages and dialogs depending on context and params
# Format:
# => page
# => injector (iff param[:mode] == :injector)
# => modal (iff param[:mode] == :modal)


class ResponseServices

  attr_accessor :controller, :action, :title, :page_url, :active_menu, :mode
  attr_reader :format

  def initialize params, session, request
    @request = request
    @format = @request.format.symbol
    @session = session
    @response = params[:response]
    @controller = params[:controller]
    @active_menu = params[:am]
    @action = params[:action]
    @trigger = params[:trigger].sub(/^"?([^"]*)"?/, '\\1') if params[:trigger]
    @title = @controller.capitalize+"#"+@action
    @invitation_token = params[:invitation_token]
    @notification_token = params[:notification_token]

    # Mode will be either
    # :modal for a dialog
    # :injector for a dialog in the context of foreign collection
    # :page for an html request
    @mode = (params[:mode] ||
        (@format == :html ? :page : :modal)).to_sym

    # Save the parameters we might want to pass back
    @meaningful_params = params.except(:controller, :action, :mode, :format) # , :id, :nocache)
  end

  # Provide a URL that reproduces the current request
  def originator
    unless @originator
      uri = URI @request.url
      uri.query = nil if (uri.query = @meaningful_params.to_param).blank?
      uri.path = uri.path.sub(/\..*/,'') # Remove any format indicator
      @originator = uri.to_s
    end
    @originator
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
    # Format refers to how to present the content: within a dialog, or on a page
    @mode = query_params[:mode]
  end

  def dialog?
    @mode == :modal || @mode == :injector
  end
  
  def is_injector
    @mode = :injector
  end
  
  # Returns true if we're in the context of a foreign page
  def injector?
    @mode == :injector
  end

  # Forward the appropriate parameters to a subsequent request
  def redirect_params options = {}
    options[:mode] = @mode
    options
  end

  # Modify a path to match the current request, asserting other options as provided
  def decorate_path path, options={}
    assert_query path, redirect_params( options )
  end

  # Return appropriate parameters for a render call, asserting defaults as necessary
  def render_params defaults = {}
    defaults.merge layout: layout
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
      if df[:format] == @format
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
    if (!options[:format]) || (options[:format].to_sym == @format) || url.match("/redirect/go") # They already match
      url
    else
      assert_query "/redirect/go", to: %Q{"#{url}"}
    end
  end

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def defer_request elements={}
    dr = {
        format: @format,
        fullpath: URI::decode(@request.fullpath)
    }.merge elements
    dr[:format] = dr[:format].to_s  # In case elements merged in a symbol
    if (dri = @session[:deferred_requests_id]) && (defreq = DeferredRequest.where(id: dri).first)
      (defreq.requests << str).uniq!
      defreq.save
    else
      @session[:deferred_requests_id] = DeferredRequest.create(:requests => [ dr ]).id
    end
    dr
  end

  def admin_view?
    @session[:admin_view]
  end

  private

  # What's the appropriate layout (in the Rails sense) for the current context?
  def layout
    case @mode
      when :injector
        "injector"
      when :page
        "application"
      else
        false
    end
  end

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
      dr[:fullpath] = assert_query URI::encode( dr[:fullpath]), :mode => @mode
      dr[:format] = dr[:format].to_sym
      dr
    end
  end

public

  # Return the class specifier for styling according to the mode
  def format_class
    @mode == :modal ? "floating" : @mode.to_s
  end

  # Used for targeting a stream to either the page or part of a dialog
  def container_selector
    @mode == :modal ? "div.dialog" : "div.container"
  end

  def page_title
    "RecipePower | #{@title}"
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

  # If there's a deferred request that can be expressed as a trigger, do so.
  def pending_modal_trigger
    trigger =
        if @trigger # A modal dialog has been embedded in the USL as the trigger param
          assert_query @trigger, mode: :modal
        elsif  (dr = pending_request) &&
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
      options[:class] << " preload trigger"
      options[:path] = Rails.application.routes.url_helpers.accept_user_invitation_path(invitation_token: @invitation_token)
    elsif @notification_token
      user = Notification.find_by_notification_token(@notification_token).target
      options[:label] = "Take Share"
      options[:path] = Rails.application.routes.url_helpers.new_user_session_path(user: {id: user.id, username: user.username})
      options[:class] << " preload trigger"
    else
      options[:label] = "Sign Me Up"
      options[:class] << " preload"
      options[:selector] = "div.dialog.signup"
      options[:path] = Rails.application.routes.url_helpers.new_user_registration_path()
    end
    options
  end

end

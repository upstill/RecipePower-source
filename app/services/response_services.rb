# Class to govern production of pages and dialogs depending on context and params
# Format:
# => page
# => injector (iff param[:mode] == :injector)
# => modal (iff param[:mode] == :modal)


class ResponseServices

  attr_accessor :controller, :action, :title, :page_url, :active_menu, :mode, :specs, :item_mode, :controller_instance
  attr_reader :format, :trigger

  def initialize params, session, request
    @request = request
    # @requestpath = request.fullpath
    @format = @request.format.symbol
    @session = session
    @response = params[:response]
    @controller = params[:controller]
    @active_menu = params[:am]
    @action = params[:action]
    # A trigger is a request for a popup, embedded in the query string
    @trigger = params[:trigger].sub(/^"?([^"]*)"?/, '\\1') if params[:trigger]
    @title = @controller.capitalize+"#"+@action
    @invitation_token = params[:invitation_token]
    @notification_token = params[:notification_token]

    # How composites are presented: :table, :strip, :masonry, :feed_entry, :card
    # ...thus governing how individuals are presented
    @item_mode = params[:item_mode].to_sym if params[:item_mode]

    # Mode will be either
    # :modal for a dialog
    # :injector for a dialog in the context of foreign collection
    # :page to render the whole page (for an html request)
    @mode = (params[:mode] || :page).to_sym
        # (@format == :html ? :page : :modal)).to_sym

    # Save the parameters we might want to pass back
    @meaningful_params = params.except :controller, :action, :mode, :format # , :id, :nocache
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
    options[:mode] = @mode unless @mode == :page
    options
  end

  # Modify a path to match the current request, asserting other options as provided
  def decorate_path path, options={}
    assert_query path, redirect_params( options )
  end

  # Return appropriate parameters for a render call, asserting defaults as necessary
  def render_params defaults = {}
    defaults.merge layout:
                       case @mode
                         when :injector
                           "injector"
                         when :page
                           "application"
                         else
                           false
                       end
  end

  def admin_view?
    @session[:admin_view]
  end

  # Return the appropriate template for the current controller and action, suitable for render :template
  # OR, start with a controller class and filename, looking for that file in the class hierarchy
  # NB The reason that this exists is to go through the standard search path
  def find_view ctrl_class=nil, file=nil
    ctrl_class ||= controller_instance.class
    file ||= action.to_s
    ctrl_class.ancestors.each { |anc|
      if path = anc.instance_variable_get(:@controller_path)
        return "#{path}/#{file}" if File.exists?(Rails.root.join("app", "views", path, "#{file}.html.erb"))
        break if path == "application"
      end
    }
    "#{controller_instance.class.ancestors[0].controller_path}/#{action}" # This will crash, but oh well...
  end

  public

  # Return the class specifier for styling according to the mode
  def format_class
    @mode == :modal ? "floating" : @mode.to_s
  end

  # Used for targeting a stream to either the page or part of a dialog
  def container_selector
    @mode == :modal ? "div.dialog" : "div.pagelet"
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

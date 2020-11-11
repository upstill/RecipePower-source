# Class to govern production of pages and dialogs depending on context and params
# Format:
# => page
# => injector (iff param[:mode] == :injector)
# => modal (iff param[:mode] == :modal)


class ResponseServices

  attr_accessor :controller, :action, :title, :page_url, :active_menu, :mode, :specs, :item_mode, :controller_instance, :uuid
  attr_reader :format, :trigger, :requestpath, :referer, :notification_token, :invitation_token, :topics, :update_option
  attr_writer :user

  def self.has_worker?
    Rails.env.development? ? false : true
    true
  end

  def initialize params, session, request
    @request = request
    @requestpath = request.fullpath
    @format = @request.format.symbol
    @referer = @request.env['HTTP_REFERER']
    @session = session
    @response = params[:response]
    @controller = params[:controller]
    @active_menu = params[:am]
    if (@action = params[:action]) == 'update'
      # update option may be:
      # :save (default) to proceed normally, saving the entity
      # :preview to adopt the entity parameters WITHOUT saving it, so that the effect of changes is shown
      # :restore to ignore the entity parameters and show the entity as it exists (undoes any previews)
      @update_option = params[:updateOption]&.to_sym || :save
    end
    @nopush = params[:nopush]
    @topics = params[:topics]
    # A trigger is a request for a popup, embedded in the query string
    @trigger = params[:trigger].sub(/^"?([^"]*)"?/, '\\1') if params[:trigger]
    @title = @controller.capitalize+"#"+@action

    # How composites are presented: :table, :strip, :masonry, :feed_entry, :card
    # ...thus governing how individuals are presented
    @item_mode = params[:item_mode].to_sym if params[:item_mode]

    # Mode will be either
    # :modal for a dialog
    # :injector for a dialog in the context of foreign collection
    # :page to render the whole page (for an html request)
    @mode = (params[:mode] || :page).to_sym
        # (@format == :html ? :page : :modal)).to_sym

    # The presence of notification and invitation tokens persists them in the session until cleared
    @invitation_token = session[:notification_token]
    @notification_token = params[:notification_token] if params[:notification_token].present?
    @invitation_token = session[:invitation_token]
    @invitation_token = params[:invitation_token] if params[:invitation_token].present?

    # Save the parameters we might want to pass back
    @unsafe_params = params.to_unsafe_h # , :id, :nocache

  end

  # We provide access to the parameters hash
  def params_hash
    @unsafe_params
  end

  def user
    @user ||= User.current_or_guest
  end

  # What model is the controller addressing?
  def controller_model_class
    controller_model_name.camelize.constantize
  end

  def controller_model_name
    @controller.singularize
  end

  # Provide a URL that reproduces the current request
  def originator
    unless @originator
      uri = URI @request.url
      uri.query = @unsafe_params.except(:id, :controller, :action, :mode, :format).to_query.if_present
      uri.path = uri.path.sub(/\..*/,'') # Remove any format indicator
      @originator = uri.to_s
    end
    @originator
  end

  # Provide an array of parameters for pushState on the client such that:
  # 1) the page can be reloaded without modification
  # 2) when popping the state, reload only those portions that need to be reloaded (via JSON request)
  def push_state action=nil
    # TODO: modify originator according to action
    [ { format: 'json', queryparams: { nopush: true } }, @title, originator ] unless @nopush
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

  def title=t
    @title = t
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
  # If path is not provided, resort to the current path
  def decorate_path path=nil, options={}
    if path.is_a? Hash
      path, options = nil, path
    end
    path ||= @request.url
    assert_query path, redirect_params( options )
  end

  # Return appropriate parameters for a render call, asserting defaults as necessary
  def render_params defaults_in = {}
    defaults_out = defaults_in.clone
    defaults_out[:layout] ||=
                       case @mode
                         when :injector
                           'injector'
                         when :page
                           'application'
                         else
                           false
                       end
    defaults_out
  end

  def admin_view?
    @session[:admin_view]
  end

  # Return the appropriate template for the current controller and action, suitable for render :template
  # OR, start with a model_name and filename, looking for that file in the corresponding controller's class hierarchy
  # NB The reason that this exists is to go through the standard search path
  def find_view model_name=nil, file=nil
    controller_name = model_name ? "#{model_name.name.pluralize}Controller" : controller_instance.class.to_s

    # We keep a cache of controller/file combos to avoid all the rigmarole of lookup
    @@Views ||= {}
    if cached_view = @@Views[cache_index = "#{controller_name}#{file}"]
      return cached_view
    end

    # Rigmarole required!
    ctrl_class =
    if model_name
      begin
        controller_name.constantize
      rescue
        return "#{model_name.collection}/#{file}"
      end
    else
      controller_instance.class
    end
    file ||= action.to_s
    ctrl_class._prefixes.each { |path|
      return (@@Views[cache_index] = "#{path}/#{file}") if File.exists?(Rails.root.join("app", "views", path, "#{file}.html.erb"))
    } if ctrl_class
    "#{controller_instance.class.ancestors[0].controller_path}/#{action}" # This will crash, but oh well...
  end

  public

  # Return the class specifier for styling according to the mode
  def format_class
    @mode == :modal ? 'floating' : @mode.to_s
  end

  # Used for targeting a stream to either the page or part of a dialog
  def container_selector
    @mode == :modal ? 'div.dialog' : 'div.pagelet'
  end

  def home_page?
    controller == 'pages' && action == 'home'
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

  # Lookup the user to whom the current invitation token pertains
  def pending_invitee
    unless @pending_invitee
      @pending_invitee = User.find_by_invitation_token(invitation_token, false) if invitation_token
      # If the invitation is to the current user, we can safely clear the pending invitation
      invitation_token = nil if @pending_invitee && user && (@pending_invitee == user)
    end
    @pending_invitee
  end

  # Set the invitation_token and store it in the @session
  def invitation_token= it
    if @invitation_token = it
      @session[:invitation_token] = it
    else
      @session.delete :invitation_token
    end
  end

  def pending_notification
    @notification ||= ActivityNotification::Notification.find_by(id: @notification_token) if @notification_token # find_by_notification_token(@notification_token) if notification_token
  end

  # Process the current notification and provide an alert
  def do_notification
    if (notif = pending_notification) && (@controller_instance.current_user.id == notif.target.id)
      # A pending notification gets accepted, with any side effects
      # All is well; clear the notification
      notif.open!
      event = notif.notifiable
      @controller_instance.flash.now[:notice] = event.act notif  # Invoke the event's action-on-open
      notification_token = nil # Clear the notification
    end
  end

  # Set the notification_token and store it in the @session
  def notification_token= it
    if @notification_token = it
      @session[:notification_token] = it
    else
      @session.delete :notification_token
    end
  end

  # When a user signs out, maintain pending invitation and notification tokens
  def restore_tokens
    @session[:invitation_token] = @invitation_token if @invitation_token
    @session[:notification_token] = @notification_token if @notification_token
  end

end

# Class to govern production of pages and dialogs depending on context and params
# Contexts:
# => injector
# => modal
# => browser
# Format:
# => json: return response structure with directive/data pairs
# => html: return page, possibly with dialog embedded
# => js: remote request: return data with js to apply it
# Presentation:
# => page
# => modal
class ResponseServices

  attr_accessor :action

  def initialize params, session, request
    @request = request
    @session = session
    @response = params[:response]
    @action = params[:action]
    @area = params[:area]
    @layout = params[:layout]
    @partial = !params[:partial].blank?
    # Target is one of "desktop", "mobile" and "injector"
    @target = (params[:target] || "desktop") unless @session[:mobile]
    # Format refers to how to present the content: within a dialog, or on a page
    @format = (params[:format] || "page")
    @format = "dialog" if (params[:how] == "modal")
  end

  # Change the response parameters to accommodate late-breaking information, e.g. the
  # parameters that come in via omniauth
  def amend params={}
    @target = params[:target] if params[:target] unless @session[:mobile]
    # Format refers to how to present the content: within a dialog, or on a page
    @format = params[:format] if params[:format]
    @format = "dialog" if params[:how] && (params[:how] == "modal")
  end
  
  def is_dialog
    @format = "dialog"
  end
  
  def dialog?
    @format == "dialog"
  end
  
  def is_injector
    @target = "injector"
  end
  
  # Returns true if we're in the context of a foreign page
  def injector?
    # defined?(@area) && (@area == "at_top" || @area == "injector")
    @target == "injector"
  end
  
  # True if we are to render a whole page
  def page?
    @area == "page" || @format == "page"
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
    klass = (options_in[:class] || "")+" modal-yield"
    options_in.merge  area: @area, class: klass
  end
  
  # Forward the appropriate parameters to a subsequent request
  def redirect_params options = {}
    options[:target] = "injector" if injector?
    options[:how] = "modal" if dialog?
    options
  end

  # Modify a path to match the current request, asserting other options as provided
  def decorate_path path, options={}
    assert_query path, redirect_params( options )
  end

  # What's the appropriate layout for the current context?
  def layout
    case 
    when mobile?
      "jqm"
    when dialog?
      false
    when injector?
      "injector"
    when page?
      "application"
    else
      false
    end
  end
  
  # Return appropriate render parameters, asserting defaults as necessary
  def render_params defaults = {}
    @area = defaults[:area] if defaults[:area]
    defaults.merge layout: layout
  end
  
  # Return the class specifier for styling according to the target
  def area_class
    # @area
    case
    when injector? 
      "at_top"
    when dialog?
      "floating"
    else
      "page"
    end
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

  # Save the current request pending (presumably) a login, such that deferred_request and deferred_trigger
  # can reproduce it after login. Any of the current request parameters may be
  # overridden--or other data stored--by passing them in the elements hash
  def defer_request elements={}
    dr = {
        format: @request.format.symbol,
        fullpath: URI::decode(@request.fullpath)
    }.merge elements
    dr[:format] = dr[:format].to_s
    str = YAML::dump dr
    @session[:deferred_request] = str
    dr
  end

  # If there's a deferred request that can be expressed as a trigger, do so.
  def pending_modal_trigger
    trigger =
    if (dr = pending_request) && (dr[:format] == :json)
      clear_pending_request # Delete it 'cause we're using it
      dr[:fullpath]
    end
    trigger
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

  private

  def clear_pending_request
    @session.delete :deferred_request
  end

  def pending_request
    if dr = @session[:deferred_request]
      dr = YAML::load dr
      # Ensure that the target of the deferred request agrees with that of the present request
      dr[:fullpath] = assert_query URI::encode( dr[:fullpath]), :target => ('injector' if injector?)
      dr[:format] = dr[:format].to_sym
      dr
    end
  end
end
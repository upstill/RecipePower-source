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
  def initialize params, session
    @session = session
    @response = params[:response]
    @area = params[:area]
    @layout = params[:layout]
    @partial = !params[:partial].blank?
    # Target is one of "desktop", "mobile" and "injector"
    @target = (params[:target] || "desktop") unless session[:mobile]
    # Format refers to how to present the content: within a dialog, or on a page
    @format = (params[:format] || "page")
    @format = "dialog" if (params[:how] == "modal")
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
  def redirect_params options_in = {}
    injector? ? options_in.merge( :target => "injector" ) : options_in
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

  # Modify a path to match the current request, asserting other options as provided
  def decorate_path path, options_in={}
    options_out = options_in # XXX Should be asserting current state
    assert_query path, options_out
  end
end
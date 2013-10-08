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
    @how = params[:how]
    debugger
    # Context is one of "desktop", "mobile" and "injector"
    @context = (params[:context] || "desktop") unless session[:mobile]
  end
  
  def dialog?
    @how == "modal" || @how == "modeless"
  end
  
  def is_injector
    @context = "injector"
  end
  
  # Returns true if we're in the context of a foreign page
  def injector?
    # defined?(@area) && (@area == "at_top" || @area == "injector")
    @context == "injector"
  end
  
  # True if we are to render a whole page
  def page?
    @area == "page"
  end
  
  def is_mobile(on=true)
    if on
      @session[:mobile] = true
      @context = nil
    else
      @session.delete :mobile
      @context = "desktop"
    end
  end
  
  # True if we're targetting mobile
  def mobile?
    @session[:mobile] && true
  end
  
  # Return relevant options for modal dialog
  def modal_options options_in = {}
    # XXX Should be adding 'modal-yield' to class, not replacing it
    klass = (options_in[:class] || "")+" modal-yield"
    options_in.merge  area: @area, 
                      modal: dialog?, # (@area != "page") && (@area != "at_top"), 
                      class: klass
  end
  
  # Forward the appropriate parameter to a subsequent request
  def params options_in = {}
    options = {}
    options.merge! :context => "injector" if injector?
    options_in.merge options
  end
  
  # Return appropriate render parameters, asserting defaults as necessary
  def render_params defaults = {}
    @area = defaults[:area] if defaults[:area]
    defaults.merge layout: 
      case 
      when mobile?
        "jqm"
      when dialog?
        false
      when injector?
        "injector"
      else
        "application"
      end
  end
  
  # Return the class specifier for styling according to area_class
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

end
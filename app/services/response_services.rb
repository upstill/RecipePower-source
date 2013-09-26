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
  def initialize 
    @response = params[:response]
    @area = params[:area]
    @how = params[:how]
  end
  
  def injector?
    defined?(@area) && (@area == "at_top" || @area == "injector")
  end
  
  def page?
    @area == "page"
  end
  
  # Return relevant options for modal dialog
  def modal_options options_in = {}
    # XXX Should be adding 'modal-yield' to class, not replacing it
    options_in.merge {area: @area, modal: (@area != "page") && (@area != "at_top"), class="modal-yield"}
  end
  
  # Forward the appropriate parameter to a subsequent request
  def params options_in = {}
    options_in.merge {:at_top => (@area == "at_top")}
  end
  
  # Return the class specifier for styling according to area_class
  def area_class
    @area
  end
  
end
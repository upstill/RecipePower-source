# Use 'with_format' when a controller needs to render one format for another.
# Canonical use is to render HTML to a string for passing as part of a JSON response.

def with_format(format, &block)
  old_formats = formats
  self.formats = [format]
  result = block.call
  self.formats = old_formats
  result
end

# Generalized response for dialog for a particular area
def dialog_boilerplate(action, default_area=nil, renderopts={})
  flash[:notice] = params[:notice]
  @area = params[:area]
  @layout = params[:layout]
  @partial = !params[:partial].blank?
  respond_to do |format|
    format.html {
      @area ||= "page"  
      if @area == "page" # Not partial at all => whole page
        render action, renderopts
      else
        renderopts[:layout] = (@layout || false)
        render action, renderopts # May have special iframe layout
      end
     }
    format.json { 
      @partial = true
      @area ||= (default_area || "floating")
      hresult = with_format("html") do
        # Blithely assuming that we want a modal-dialog element if we're getting JSON
        renderopts[:layout] = (@layout || false)
        render_to_string action, renderopts # May have special iframe layout
      end
      renderopts[:json] = { code: hresult, area: @area, how: "bootstrap" }
      render renderopts
    }
    format.js {
      # Must have set @partial in preparation
      renderopts[:action] = "capture"
      render renderopts
    }
  end
end
  
  # Default broad-level error report based on controller and action
  def express_error_context resource
    "Couldn't #{params[:action]} the #{resource.class.to_s.downcase}"
  end

  # Summarize base errors from a resource transaction
	def express_base_errors resource
	  resource.errors[:base].empty? ? "" : resource.errors[:base].map { |msg| content_tag(:p, msg) }.join
  end
  
  # If no preface is provided, use the generic error context
  # NB: preface can be locked out entirely by passing ""
  def express_resource_errors resource, options={}
    preface = options[:preface] || express_error_context(resource)
    base_errors = options[:with_base] ? express_base_errors(resource) : ""
    details = 
      if attribute = options[:attribute]
        (attribute.to_s.upcase+" "+enumerate_strs(resource.errors[attribute])+".")
      else
        resource.errors.full_messages.to_sentence
      end + base_errors
    preface += (details.blank? ? "." : ":<br>") unless preface.blank?
    preface+details
  end

   # Stick ActiveRecord errors into the flash for presentation at the next action
   def resource_errors_to_flash resource, options={}
     flash[:error] = express_resource_errors resource, options
   end

   # Stick ActiveRecord errors into the flash for presentation now
   def resource_errors_to_flash_now resource, options={}
     flash.now[:error] = express_resource_errors resource, options
   end

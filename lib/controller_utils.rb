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

	def base_errors resource
	  resource.errors[:base].empty? ? "" : ("PS (base errors): "+resource.errors[:base].map { |msg| content_tag(:p, msg) }.join)
  end
  
  def error_notification obj, attribute = nil, preface = nil
    sentence = attribute ? (attribute.to_s.upcase+" "+enumerate_strs(obj.errors[attribute])+".") : obj.errors.full_messages.to_sentence
    preface ||= "Problem while trying to #{params[:action]} the #{obj.class.to_s.downcase}"
    preface+(sentence.blank? ? "." : ":<br>#{sentence}")+base_errors(resource)
  end

   # Stick ActiveRecord errors into the flash for presentation at the next action
   def flash_errors obj, preface = ""
     flash[:error] = error_notification obj, nil, preface
   end

   # Stick ActiveRecord errors into the flash for presentation now
   def flash_errors_now obj, preface = ""
     flash.now[:error] = error_notification obj, nil, preface
   end

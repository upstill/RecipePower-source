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

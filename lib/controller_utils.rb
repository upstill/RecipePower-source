# Use 'with_format' when a controller needs to render one format for another.
# Canonical use is to render HTML to a string for passing as part of a JSON response.

def with_format(format, &block)
    old_formats = formats
    self.formats = [format]
    result = block.call
    self.formats = old_formats
    result
end

def dialog_boilerplate(action)
    respond_to do |format|
        format.html {      
            if @partial
                render action, :layout => false # :layout => "dlog"
            else # Not partial at all => whole page
                render action
            end
         }
         format.json { 
           @partial = "modal" unless @partial
           hresult = with_format("html") do
             # Blithely assuming that we want a modal-dialog element if we're getting JSON
             render_to_string "new", :layout => false # :layout => "dlog"
           end
           render json: { dialog: hresult, where: @partial }
         }
    end
end
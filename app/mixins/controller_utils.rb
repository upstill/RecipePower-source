# Use 'with_format' when a controller needs to render one format for another.
# Canonical use is to render HTML to a string for passing as part of a JSON response.
module ControllerUtils
  def with_format(format, &block)
    old_formats = formats
    self.formats = [format]
    result = block.call
    self.formats = old_formats
    result
  end

# Craft a string for describing an action
  def action_summary controller, action
    case controller
      when "users"
        case action
          when "collection"
            return "view someone's collection"
        end
      when "invitations"
        case action
          when "new"
            return "invite someone else"
        end
    end
    "#{action} #{controller}"
  end

# Report the current errors on a record in a nice alert div, suitable for interpolation within the
# form whose failure generated the error
  def post_resource_errors obj, options={}
    unless obj.errors.empty?
      flash_one :error, express_resource_errors(obj, options)
    end
  end

# Default broad-level error report based on controller and action
  def express_error_context resource
    "Couldn't #{params[:action]} the #{resource.class.to_s.downcase}"
  end

# Stick ActiveRecord errors into the flash for presentation at the next action
  def resource_errors_to_flash resource, options={}
    flash[:error] = view_context.express_resource_errors resource, options
  end

# Stick ActiveRecord errors into the flash for presentation now
  def resource_errors_to_flash_now resource, options={}
    flash.now[:error] = view_context.express_resource_errors resource, options
  end
end

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
      when 'lists'
        case action
          when 'contents'
            return 'inspect a treasury'
        end
    end
    "#{action} #{controller}"
  end

  # Default broad-level error report based on controller and action
  def express_error_context resource
    I18n.t "errors.action.#{params[:controller]}.#{params[:action]}.#{resource.class.model_name.i18n_key}",
           default: "Couldn't #{params[:action]} the #{resource.class.to_s.downcase}"
  end

  # Stick ActiveRecord errors into the flash for presentation at the next action
  def resource_errors_to_flash resource, options={}
    if resource.respond_to?(:errors) && resource.errors.present?
      flash[:error] = view_context.express_resource_errors(resource, options)
    end
  end

  # Stick ActiveRecord errors into the flash for presentation now
  def resource_errors_to_flash_now resource, options={}
    flash.now[:error] = view_context.express_resource_errors resource, options
  end

  def base_errors_to_flash_now resource
    errs = resource.errors[:base].collect { |errstr|
      errstr.split('"').collect { |substr| substr.capitalize unless substr.match(/^[\[\],]$/) }
    }.flatten.uniq.compact
    return if errs.blank?
    flash.now[:error] = (errs.length == 1) ? errs[0] : (errs[0...-1].join(",\n") + " and\n" + errs[-1])
  end
end

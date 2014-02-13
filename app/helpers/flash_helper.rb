# Provide the capability of displaying closeable flash messages. In general it is better to 
# wrap all such messages in a notifications div (provideed by flash_notifications) because
# 1) such messages are removed when the close-box is clicked and 2) the content may need to be replaced
module FlashHelper

  # Emit the flash_notifications for the page in a div.
  def flash_notifications_div cssclass = "flash_notifications", for_bootstrap = true
    content_tag :div, flash_all(for_bootstrap), class: cssclass
  end
  
	# Returns a selector-value pair for replacing the notifications panel due to an update event
	def flash_notifications_replacement
	  [ "div.flash_notifications", flash_notifications_div ]
	end

  # Incorporate error reporting for a resource within a form, preferring
  # any base error from the resource to the standard notification
  def form_errors_helper f, object=nil, for_bootstrap=true
    resource = object || f.object
    unless resource.errors.empty?
      if resource.errors[:base].empty?
        # We accept both ActionView form builders and simple_form builders, but only the latter has error notification
        (f && f.respond_to?(:error_notification)) ? f.error_notification : resource_errors_helper(resource)
      else 
        base_errors_helper resource, for_bootstrap
      end
    end
  end
  
  # Report the current errors on a record in a nice alert div, suitable for interpolation within the
  # form whose failure generated the error
  def resource_errors_helper obj, options={}
    unless obj.errors.empty?
      flash_one :error, express_resource_errors(obj, options )
    end
  end
  
  # Augments error display for record attributes (a la simple_form) with base-level errors
  def base_errors_helper resource, for_bootstrap = true
    flash_one :error, express_base_errors(resource), for_bootstrap
  end

  # Emit a single error panel, returning an empty string if the message is empty
  def flash_one level, message, for_bootstrap=true
    return "".html_safe if message.blank?
    if message.blank?
      hide = "hide"
    else
      hide = ""
    end
    if for_bootstrap
      bootstrap_class =
      case level
      when :success
        "alert-success"
      when :error
        "alert-danger"
      when :alert
        "alert-warning"
      when :notice
        "alert-info"
      when :guide
        "alert-guide"
      else
        level.to_s
      end
      message = "<span>#{message.html_safe}</span>".html_safe
      button = "<button class=\"close\" data-dismiss=\"alert\">&#215;</button>".html_safe
       # This message may have been cleared earlier...
      html = content_tag :div, button+message, class: "alert #{bootstrap_class} alert_block fade in #{hide}"
    else
      html = content_tag :div, message.html_safe, class: "alert #{hide}"
    end
    html.html_safe
  end
  
  def flash_all for_bootstrap=true
    flash.collect { |type, message|
      flash.delete type
      flash_one type, message, for_bootstrap
    }.join.html_safe
  end

  # Return the current flash text, suitable for popping up
  def flash_popup
    msg = flash.collect  { |type, message|
      flash.delete type
      message
    }.join.html_safe
    msg
  end
end
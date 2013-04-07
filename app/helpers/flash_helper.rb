module FlashHelper   
  # Incorporate error reporting for a resource within a form, preferring
  # any base error from the resource to the standard notification
  def form_errors_helper f, object=nil
    resource = object || f.object
    base_errors = base_errors_helper resource
    if base_errors.blank?
      # We accept both ActionView form builders and simple_form builders, but only the latter has error notification
      f.respond_to?(:error_notification) ? f.error_notification : resource_errors_helper(resource)
    else 
      base_errors
    end
  end
  
  # Augments error display for record attributes (a la simple_form) with base-level errors
  def base_errors_helper resource
    flash_one :error, express_base_errors(resource)
  end
  
  # Report the current errors on a record in a nice alert div, suitable for interpolation within the
  # form whose failure generated the error
  def resource_errors_helper obj, options={}
    unless obj.errors.empty?
      flash_one :error, express_resource_errors(obj, options )
    end
  end

  def flash_one level, message, for_bootstrap=true
    return "".html_safe if message.blank?
    if for_bootstrap
      bootstrap_class =
      case level
      when :success
        "alert-success"
      when :error
        "alert-error"
      when :alert
        "alert-block"
      when :notice
        "alert-info"
      when :guide
        "alert-guide"
      else
        level.to_s
      end
       # This message may have been cleared earlier...
      html = <<-HTML
        <div class="alert #{bootstrap_class} alert_block fade in">
          <button class="close" data-dismiss="alert">&#215;</button>
          #{message}
        </div>
        HTML
    else
      html = %Q{<div class="generic_alert" style="display: block; background-color:#fcf8e3; border: 1px solid #f9f6dc; padding:3px; border:3px;">#{message}</div>}
    end
    flash.delete(level)
    html.html_safe
  end
  
  def flash_all for_bootstrap=true
    flash.collect { |type, message| 
      flash_one type, message, for_bootstrap 
    }.join.html_safe
  end
  
  # Emit the flash_notifications for the page in a div.
  def flash_notifications
    content_tag :div, flash_all, class: "flash_notifications"
  end
  
	# Returns a selector-value pair for replacing the notifications panel due to an update event
	def flash_notifications_replacement
	  [ "div.flash_notifications", flash_notifications ]
	end
end
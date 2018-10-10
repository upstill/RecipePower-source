# Provide the capability of displaying closeable flash messages. In general it is better to 
# wrap all such messages in a notifications div (provideed by flash_notifications) because
# 1) such messages are removed when the close-box is clicked and 2) the content may need to be replaced
module FlashHelper

  # Emit the flash_notifications for the page in a div.
  def flash_notifications_div cssclass = 'flash_notifications', for_bootstrap = true
    content = flash_all(for_bootstrap)
    styles = { class: cssclass }
    styles[:style] = 'display:none;' if content.blank?
    content_tag :div, content, styles
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
        (f && f.respond_to?(:error_notification)) ? f.error_notification : resource_errors_to_flash(resource)
      else 
        base_errors_helper resource, for_bootstrap
      end
    end
  end

  # For a form where resource errors might be triggered by unavailable fields, add the errors to :base
  def make_base_errors_except *args
    return if resource.errors.empty?
    resource = args.shift
    (resource.errors.keys - args).each { |errkey|
      next if errkey == :base
      resource.errors[errkey].each { |error|
        resource.errors.add :base, "#{errkey} #{error}"
      }
    }
  end

  # Augments error display for record attributes (a la simple_form) with base-level errors
  def base_errors_helper resource, for_bootstrap = true
    flash_one :error, express_base_errors(resource), for_bootstrap
  end

  # Emit a single error panel, returning an empty string if the message is empty
  def flash_one level, message, for_bootstrap=true
    return "".html_safe if message.blank?
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
      html = content_tag :div, button+message, class: "alert #{bootstrap_class} alert_block fade in"
    else
      html = content_tag :div, message.html_safe, class: "alert"
    end
    html.html_safe
  end
  
  def flash_all for_bootstrap=true
    flash.collect { |type, message|
      flash.delete type
      flash_one type.to_sym, message, for_bootstrap
    }.join.html_safe
  end

  def flash_usurp separator='<br\>'
    flash.collect { |type, message|
      flash.delete type
      message
    }.join(separator).html_safe
  end

  # Collect the flash messages in a hash
  def flash_hash
    fh = {}
    flash.each { |type, message| fh[type] = message }
    fh
  end

  # For passing through a redirect, enclose the collected flash messages in a hash
  def flash_param
    fh = flash_hash
    fh.count > 0 ? { flash: fh } : {}
  end

  # Provide a hash suitable for including in a JSON response for driving a flash notification
  # 'all' true incorporates all extant messages in the popup
  def flash_notify resource=nil, popup_only=false
    # Collect any errors from the resource
    if resource==true || resource==false
      resource, popup_only = nil, resource
    else
      resource_errors_to_flash resource
    end
    if flash.empty?
      return { "clear-flash" => true }
    end
    result = {}
    if msg = flash[:alert]
      result[:alert] = msg
      flash.delete :alert
    end
    if popup_only
      result[:popup] = flash.collect  { |type, message|
        flash.delete type
        message
      }.join.html_safe
    else # Keep all flashes in their intended form
      if msg = flash[:popup]
        result[:popup] = msg
        flash.delete :popup
      end
      # Others get passed through for the flash panel
      flash.each  { |type, message|
        result["flash-#{type}"] = message
        flash.delete type
        message
      }
    end
    result
  end
end
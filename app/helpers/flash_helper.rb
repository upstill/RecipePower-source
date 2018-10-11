# Provide the capability of displaying closeable flash messages, either in a dialog or on the page. In general it is better to
# wrap all such messages in a notifications div (provided by flash_notifications_div) because
# 1) such messages are removed when the close-box is clicked and 2) the content may need to be replaced
module FlashHelper

  # Emit the flash_notifications for the page in a div.
  # If there are no notifications, present an empty, invisible panel
  def flash_notifications_div
    content = flash_all
    content_tag :div,
                content,
                {
                    class: 'flash_notifications',
                    style: ('display:none;' if content.blank?)
                }.compact
  end

  # Returns a selector-value pair for replacing the notifications panel to report errors and status
  def flash_notifications_replacement
    ['div.flash_notifications', flash_notifications_div]
  end

  # Incorporate error reporting for a resource within a form, preferring
  # any base error from the resource to the standard notification
  def form_errors_helper f, object=nil
    resource = object || f.object
    unless resource.errors.empty?
      if resource.errors[:base].empty?
        # We accept both ActionView form builders and simple_form builders, but only the latter has error notification
        (f && f.respond_to?(:error_notification)) ? f.error_notification : resource_errors_to_flash(resource)
      else
        flash_one :error, express_base_errors(resource)
      end
    end
  end

  # Emit a single error panel as a div of classes defined for Bootstrap
  # RETURNS: an empty, html_safe string if the message is empty
  # NB: we map from flash message types :alert, :notice and :error to the corresponding Bootstrap alert types
  def flash_one level, message
    return ''.html_safe if message.blank?
    bootstrap_class =
        case level
          when :success, :notice
            'alert-success'
          when :danger, :error
            'alert-danger'
          when :alert
            'alert-warning'
          when :notice
            'alert-info'
          else
            level.to_s
        end
    message = content_tag :span, message.html_safe
    button = content_tag :button, '&#215'.html_safe, class: 'close', data: {dismiss: 'alert'}
    # This message may have been cleared earlier...
    content_tag :div, safe_join([button, message]), class: "alert #{bootstrap_class} alert_block fade in"
  end

  # Collect all flash message panels and join them together
  def flash_all
    safe_join flash.collect { |type, message|
                flash.delete type
                flash_one type.to_sym, message
              }
  end

  # Collect all flash messages joined with a line-break
  def flash_strings
    safe_join flash.collect { |type, message|
                flash.delete type
                message
              }, '<br\>'.html_safe
  end

  # Provide a hash suitable for including in a JSON response to present a flash notification
  # which replaces any extant notification.
  # 'all' true incorporates all extant messages in the popup
  def flash_notify resource=nil, popup_only=false
    if resource==true || resource==false
      resource, popup_only = nil, resource
    else
      # Collect any errors from the resource into the flash
      resource_errors_to_flash resource
    end
    if flash.empty?
      return {'clear-flash' => true} # Signifies that the extant flash should be cleared
    end
    result = {}
    if msg = flash[:alert]
      result[:alert] = msg
      flash.delete :alert
    end
    if popup_only
      result[:popup] = flash_strings
    else # Keep all flashes in their intended form
      if msg = flash[:popup]
        result[:popup] = msg
        flash.delete :popup
      end
      # Others get passed through for the flash panel
      flash.each { |type, message|
        result["flash-#{type}"] = message
        flash.delete type
        message
      }
    end
    result
  end
end

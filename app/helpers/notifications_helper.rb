module NotificationsHelper

  def notifications_locator
    'li#home-navtab div.notification_wrapper'
  end

  def notifications_replacement target, options={}
      # Relist the notifications
      rendering = with_format('html') {
        render_notifications_of target, options
      }
      [ notifications_locator, rendering ]
  end

  def notifications_format_subject notification, subject
    subject << ( " and #{notification.group_member_notifier_count} other" +
        (source.present? ? source.printable_type.pluralize.downcase : 'people')
    ) if false && notification.group_member_notifier_exists?
    content_tag :strong, subject
  end

  def check_for_notifications
    script =
    with_format('js') {
      render 'activity_notification/notifications/default/check_notifications',
             notification_count: current_user.unopened_notification_count
    } if current_user
    javascript_tag script
  end

end
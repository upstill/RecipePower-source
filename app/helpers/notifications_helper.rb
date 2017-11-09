module NotificationsHelper
  def notifications_replacement target, options={}
      # Relist the notifications
      rendering = with_format 'html' do
        render_notifications_of target, options
      end
      [ 'div.notification_wrapper', rendering ]
  end

  def notifications_format_subject notification, subject
    subject << ( " and #{notification.group_member_notifier_count} other" +
        (source.present? ? source.printable_type.pluralize.downcase : 'people')
    ) if false && notification.group_member_notifier_exists?
    content_tag :strong, subject
  end

end
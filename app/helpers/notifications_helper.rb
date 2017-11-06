module NotificationsHelper
  def notifications_replacement target, options={}
      # Relist the notifications
      rendering = with_format 'html' do
        render_notifications_of target, options
      end
      [ 'div.selectable.modal-body.notifications div.notification_wrapper', rendering ]
  end

end
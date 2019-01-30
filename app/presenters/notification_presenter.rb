class NotificationPresenter
  attr_reader :viewer, :notification, :template

  def initialize notification, template, viewer=User.current_or_guest
    @notification = notification
    @template = template
    @viewer = viewer
  end

  # If the notification has a preferred page to present when answered, it's declared here
  def referral_path
    case evt = notification.target
      when InvitationSentEvent
        polymorphic_path( [:show, evt.shared.decorate.as_base_class]) if evt.shared
      when SharedEvent
        polymorphic_path [:show, evt.shared.decorate.as_base_class]
    end
  end

  def render
    # Construct the path to the notification partial
    template.with_format("html") do
      template.render "activity_notification/notifications/default/#{notification.key.gsub /\./, '/'}", notification: notification
    end
  end

  def selector
    "div.#{cssclass}"
  end

  def cssclass
    "notification_#{notification.id}"
  end

end

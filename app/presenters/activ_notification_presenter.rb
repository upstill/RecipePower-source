class ActivNotificationPresenter < BasePresenter
  presents :notification

  # If the notification has a preferred page to present when answered, it's declared here
  def referral_path
    case evt = notification.target
      when InvitationSentEvent
        polymorphic_path( [:show, evt.shared]) if evt.shared
      when SharedEvent
        polymorphic_path [:show, evt.shared]
    end
  end
end
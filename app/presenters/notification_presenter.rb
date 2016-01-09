class NotificationPresenter < BasePresenter
  presents :notification
  delegate :source, :target, :shared, :typesym, :notification_token, :accepted, :shared, :autosave, to: :notification

  def ack_link
    h.notifications_accept_path notification_token: notification_token
  end

  def verbalization link_options={}
    case typesym
      when :share
        "#{homelink source, link_options} shared <br>#{homelink shared, link_options}".html_safe
      when :make_friend
        "#{homelink source, link_options} followed you".html_safe
    end
  end

  def response_link
    case typesym
      when :share
        polymorphic_path [:collect, shared]
      when :make_friend
        polymorphic_path [:collect, source]
    end
  end

  def response_label
    case typesym
      when :share
        'Collect'
      when :make_friend
        "Follow #{source.handle}"
    end
  end
end
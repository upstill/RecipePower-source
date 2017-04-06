class NotificationPresenter < BasePresenter
  presents :notification
  delegate :source, :target, :shared, :typesym, :notification_token, :accepted, :shared, :autosave, to: :notification

  # Path to accept the notification without acting on it
  def accept_path
    h.notifications_accept_path notification_token: notification_token
  end

  # Path to BOTH accept the notification and act on it
  def act_path
    h.notifications_act_path notification_token: notification_token
  end

  # Where to go when the notification is to be acted upon. NB: for the use of NotificationController only
  def action_path
    case typesym
      when :share
        polymorphic_path [:collect, shared]
      when :make_friend
        polymorphic_path [:collect, source]
    end
  end

  # Where to go when the notification is to be acted upon. NB: for the use of NotificationController only
  def post_action_path
    case typesym
      when :share
        polymorphic_path shared
      when :make_friend
        polymorphic_path source
    end
  end

  def verbalization link_options={}
    case typesym
      when :share
        "#{homelink source, link_options} shared <br>#{homelink shared, link_options}".html_safe
      when :make_friend
        "#{homelink source, link_options} followed you".html_safe
    end
  end

  def report_accepted
    case typesym
      when :share
        collection_str = (viewer == source) ? 'your collection' : "the collection of #{homelink source}."
        "#{homelink shared} now appearing in #{collection_str}".html_safe
      when :make_friend
        "#{homelink source, link_options} followed you".html_safe
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

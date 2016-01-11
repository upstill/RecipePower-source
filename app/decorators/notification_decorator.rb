class NotificationDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def title
    ''
  end

  def external_link
    ''
  end

  # Fulfill the action implicit in the notification
  def act
    success_msg =
    case typesym
      when :share
        entity = shared
        target.collect entity
        "'#{entity.decorate.title}' now appearing in your collection."
      when :make_friend
        entity = source
        target.collect entity
        "You're now following #{entity.handle}."
    end
    if entity && entity.errors.any?
      ("Problem with #{entity.class}:" +
      entity.errors.collect { |attr,msg| "#{attr} #{msg}" }.join('<br>')).html_safe
    else
      success_msg
    end
  end
end
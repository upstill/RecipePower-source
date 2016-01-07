class NotificationDecorator < Draper::Decorator
  include Templateer
  delegate_all

  def title
    ''
  end

  def external_link
    ''
  end

end
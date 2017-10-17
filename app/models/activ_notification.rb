class ActivityNotification::Notification
  alias_attribute :notification_token, :id
  attr_accessible :notification_token

  def self.find_by_notification_token token
    self.find_by id: token
  end
end

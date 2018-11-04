=begin
class Notification
  # attr_accessible :info, :source_id, :target_id,
                  :notification_type,
                  :accepted, :shared, :autosave
  serialize :info
  
  belongs_to :target, :class_name => 'User'
  belongs_to :source, :class_name => 'User'
  belongs_to :shared, :polymorphic => true
  before_create :generate_token

  include Typeable
  typeable( :notification_type, 
      Untyped: ['Untyped', 0 ],
      :share => ['Share', 1], # Shared a collectible with
      :make_friend => ['Friended', 2] # Source added target as friend
  )

  # Do whatever is entailed by the notification
  def accept
    msg = ""
    case typesym
    when :share
      shared.collectible_user_id = target_id
      shared.be_collected
      msg = "'#{shared.decorate.title}' now appearing in your collection"
    when :make_friend
    end
    self.accepted = true
    save
    msg
  end

  protected

  # Generate a unique random token for accepting a notification sent via email
  def generate_token
    self.notification_token = loop do
      random_token = Digest::SHA1.hexdigest([Time.now, rand].join)
      break random_token unless Notification.where(notification_token: random_token).exists?
    end
  end

end

  class ActivityNotification::Notification
    alias_attribute :notification_token, :id
    # attr_accessible :notification_token
    before_create :generate_token

    def self.find_by_notification_token token
      self.find_by id: token
    end
#    protected

    # Generate a unique random token for accepting a notification sent via email
    def generate_token
      self.notification_token = loop do
        random_token = Digest::SHA1.hexdigest([Time.now, rand].join)
        break random_token unless self.where(notification_token: random_token).exists?
      end
    end
  end
=end

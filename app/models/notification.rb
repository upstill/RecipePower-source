class Notification < ActiveRecord::Base
  attr_accessible :info, :source_id, :target_id, :notification_type, :typenum, :typesym, :acceptance_token
  serialize :info
  
  belongs_to :target, :class_name => "User"
  belongs_to :source, :class_name => "User"
  before_create :generate_token
  
  include Typeable
  typeable( :notification_type, 
      Untyped: ["Untyped", 0 ],
      :share_recipe => ["Share Recipe", 1], # Shared a recipe with
      :make_friend => ["Friended", 2] # Source added target as friend
  )

  protected

  # Generate a unique random token for accepting a notification sent via email
  def generate_token
    self.acceptance_token = loop do
      random_token = Digest::SHA1.hexdigest([Time.now, rand].join)
      break random_token unless Notification.where(acceptance_token: random_token).exists?
    end
  end
  
end

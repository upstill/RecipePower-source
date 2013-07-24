class Notification < ActiveRecord::Base
  attr_accessible :info, :source_id, :target_id, :notification_type, :typenum, :typesym, :acceptance_token
  serialize :info
  
  belongs_to :target, :class_name => "User"
  belongs_to :source, :class_name => "User"
  
  include Typeable
  
  typeable( :notification_type, 
      Untyped: ["Untyped", 0 ],
      :share_recipe => ["Share Recipe", 1], # Shared a recipe with
      :make_friend => ["Friended", 2] # Source added target as friend
  )
  
end

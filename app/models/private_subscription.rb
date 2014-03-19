class PrivateSubscription < ActiveRecord::Base
  attr_accessible :user, :tag
  belongs_to :user
  belongs_to :tag
end

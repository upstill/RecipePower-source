module Sharable
  extend ActiveSupport::Concern

  included do

    has_many :shares, :as => :shared, :dependent => :destroy, :class_name => 'Notification'

  end
end
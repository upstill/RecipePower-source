class DeferredRequest < ActiveRecord::Base
  serialize :requests
  attr_accessible :requests
end

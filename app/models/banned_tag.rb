# A BannedTag is one that is disqualified from use in robo-tagging
class BannedTag < ActiveRecord::Base
  attr_accessible :normalized_name
end

class Tagging < ActiveRecord::Base
  attr_accessible :entity_id, :entity_type, :is_definition, :tag_id, :user_id
end

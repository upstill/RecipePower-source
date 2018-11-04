class TagsCache < ApplicationRecord
  self.primary_key = 'session_id'
  # attr_accessible :tags, :session_id
  serialize :tags

  has_many :results_caches, :foreign_key => 'session_id'
end

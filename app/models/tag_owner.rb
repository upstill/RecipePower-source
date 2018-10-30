class TagOwner < ApplicationRecord
    belongs_to :owner, class_name: 'User', foreign_key: 'user_id'
    belongs_to :tag
    # before_save :ensure_unique
end

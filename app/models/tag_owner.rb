class TagOwner < ActiveRecord::Base
    belongs_to :user
    belongs_to :tag
    # before_save :ensure_unique
end

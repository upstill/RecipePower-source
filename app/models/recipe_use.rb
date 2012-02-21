class RecipeUse < ActiveRecord::Base
    belongs_to :recipe
    belongs_to :user
    # before_save :ensure_unique
    attr_accessible :comment

    # When saving a "new" use, make sure it's unique
    def ensure_unique
puts "Ensuring uniqueness of user #{self.user_id.to_s} to recipe #{self.recipe_id.to_s}"
    end
end

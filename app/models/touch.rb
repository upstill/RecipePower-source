class Touch < ActiveRecord::Base
    belongs_to :touching, :class_name => "Recipe", :foreign_key => "recipe_id"
    belongs_to :user
    
  # Register that a user has touched a recipe   
  def self.touch user, recipe
    user = user.id if user.kind_of? User
    recipe = recipe.id if recipe.kind_of? User
    if rcd = self.find_or_create_by_user_id_and_recipe_id( user, recipe )
      rcd.touch 
    end
  end
  
  # Present the time-since-touched in a text format
  def self.touch_date(rid, uid)
    if rr = self.where(recipe_id: rid, user_id: uid).first
      rr.updated_at
    end
  end
  
end

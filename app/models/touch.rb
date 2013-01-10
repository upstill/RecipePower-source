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
  
  # Move all touchings to the corresponding rcpref
  def self.fix n=-1
    self.all.each { |rcd| 
      rcp = rcd.touching
      if rcp.users.exists? rcd.user_id
        before = rcp.touch_date(rcd.user_id)
        task = rcp.uptouch(rcd.user_id, rcd.updated_at) ? "Uptouched" : nil
      else
        before = "n/a"
        Rcpref.record_timestamps=false
        attrs = rcd.attributes.slice(*%w{ recipe_id user_id created_at updated_at })
        attrs["in_collection"] = false
        Rcpref.create attrs
        Rcpref.record_timestamps=true
        task = "Created new ref for"
      end
      after = rcp.touch_date(rcd.user_id)
      if task
        logger.debug "#{task} recipe ##{rcd.recipe_id.to_s} for touch on time #{rcd.updated_at}"
        logger.debug "...before, time was #{before}"
        logger.debug "...after, time is #{after}"
        n = n-1
      end
      return if n==0
    }
  end
  
  # Present the time-since-touched in a text format
  def self.touch_date(rid, uid)
    if rr = self.where(recipe_id: rid, user_id: uid).first
      rr.updated_at
    end
  end
  
end

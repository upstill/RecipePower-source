class ChangeRoleReferentToDishReferent < ActiveRecord::Migration
  def up
	Referent.where(type: 'RoleReferent').each { |rr|
	  dr = rr.becomes(DishReferent)
	  dr.type = 'DishReferent'
	  dr.save
        }
  end
  def down
	Referent.where(type: 'DishReferent').each { |rr|
	  dr = rr.becomes(RoleReferent)
	  dr.type = 'RoleReferent'
	  dr.save
        }
  end
end

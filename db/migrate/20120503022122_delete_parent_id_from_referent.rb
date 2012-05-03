class DeleteParentIdFromReferent < ActiveRecord::Migration
  def up
     remove_column :referents, :parent_id
  end

  def down
     add_column :referents, :parent_id, :integer
  end
end

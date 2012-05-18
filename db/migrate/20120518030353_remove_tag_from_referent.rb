class RemoveTagFromReferent < ActiveRecord::Migration
  def up
    remove_column :referents, :tag
    add_column :referents, :tag_id, :integer
  end

  def down
    remove_column :referents, :tag_id
    add_column :referents, :tag, :integer
  end
end

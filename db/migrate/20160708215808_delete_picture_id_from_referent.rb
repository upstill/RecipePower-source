class DeletePictureIdFromReferent < ActiveRecord::Migration
  def up
    remove_column :referents, :picture_id
  end
  def down
    add_column :referents, :picture_id, :integer
  end
end

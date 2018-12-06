class DeletePictureIdFromReferent < ActiveRecord::Migration[4.2]
  def up
    remove_column :referents, :picture_id
  end
  def down
    add_column :referents, :picture_id, :integer
  end
end

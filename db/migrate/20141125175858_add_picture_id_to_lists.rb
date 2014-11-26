class AddPictureIdToLists < ActiveRecord::Migration
  def change
    add_column :lists, :picture_id, :integer
  end
end

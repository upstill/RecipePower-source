class AddPictureIdToReferents < ActiveRecord::Migration
  def change
    add_column :referents, :picture_id, :integer
  end
end

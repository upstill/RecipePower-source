class AddPictureIdToReferents < ActiveRecord::Migration[4.2]
  def change
    add_column :referents, :picture_id, :integer
  end
end

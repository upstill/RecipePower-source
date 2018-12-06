class AddPictureIdToPageRef < ActiveRecord::Migration[4.2]
  def change
    add_column :page_refs, :picture_id, :integer
  end
end

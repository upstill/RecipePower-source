class AddPictureIdToPageRef < ActiveRecord::Migration
  def change
    add_column :page_refs, :picture_id, :integer
  end
end

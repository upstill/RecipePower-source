class AddThumbnailIdToReference < ActiveRecord::Migration
  def change
    add_column :references, :thumbnail_id, :integer
    add_column :sites, :thumbnail_id, :integer

  end
end

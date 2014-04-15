class AddThumbnailIdToReference < ActiveRecord::Migration
  def change
    add_column :references, :affiliate_id, :integer
    add_column :references, :affiliate_type, :string
    add_column :sites, :thumbnail_id, :integer

  end
end

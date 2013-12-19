class DeleteTagsSerializedFromSites < ActiveRecord::Migration
  def change
	remove_column :sites, :tags_serialized, :text
  end
end

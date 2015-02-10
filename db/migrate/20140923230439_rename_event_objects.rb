class RenameEventObjects < ActiveRecord::Migration
  def change
	rename_column :rp_events, :object_id, :direct_object_id
	rename_column :rp_events, :object_type, :direct_object_type
	rename_column :rp_events, :object2_id, :indirect_object_id
	rename_column :rp_events, :object2_type, :indirect_object_type
  end
end

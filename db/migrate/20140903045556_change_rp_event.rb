class ChangeRpEvent < ActiveRecord::Migration
  def change
	rename_column :rp_events, :subject_id, :object_id
	rename_column :rp_events, :subject_type, :object_type
	rename_column :rp_events, :target_id, :object2_id
	rename_column :rp_events, :target_type, :object2_type
  end
end

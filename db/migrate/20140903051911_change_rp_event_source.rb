class ChangeRpEventSource < ActiveRecord::Migration
  def change
    rename_column :rp_events, :source_id, :subject_id
    rename_column :rp_events, :source_type, :subject_type
  end
end

class AddTypeToRpEvent < ActiveRecord::Migration[4.2]
  def up
    RpEvent.delete_all
    add_column :rp_events, :type, :string
    add_column :rp_events, :status, :integer, default: 0
    add_column :rp_events, :dj_id, :integer
    remove_column :rp_events, :verb, :string
  end
  def down
    add_column :rp_events, :verb, :string
    remove_column :rp_events, :type, :string
    remove_column :rp_events, :status
    remove_column :rp_events, :dj_id
  end
end

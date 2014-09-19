class RemoveStatusFromRcprefs < ActiveRecord::Migration
  def up
	remove_column :rcprefs, :status
  end
  def down
	add_column :rcprefs, :status, :integer, default: 8
  end
end

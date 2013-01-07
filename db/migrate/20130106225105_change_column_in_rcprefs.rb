class ChangeColumnInRcprefs < ActiveRecord::Migration
  def up
    change_column :rcprefs, :status, :integer, :default => 8
  end

  def down
    change_column :rcprefs, :status, :integer
  end
end

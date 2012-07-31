class ChangeRcprefs < ActiveRecord::Migration
  def up
      change_column :rcprefs, :private, :boolean, :default => false
  end

  def down
      change_column :rcprefs, :private, :boolean, :default => true
  end
end

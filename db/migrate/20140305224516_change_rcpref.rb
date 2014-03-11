class ChangeRcpref < ActiveRecord::Migration
  def up
      change_column :rcprefs, :in_collection, :boolean, :default => true
  end

  def down
      change_column :rcprefs, :in_collection, :boolean, :default => false
  end
end

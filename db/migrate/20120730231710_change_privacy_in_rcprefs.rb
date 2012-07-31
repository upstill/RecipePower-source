class ChangePrivacyInRcprefs < ActiveRecord::Migration
  def up
    remove_column :rcprefs, :privacy
    add_column :rcprefs, :private, :boolean, :default => true
  end

  def down
    remove_column :rcprefs, :private
    add_column :rcprefs, :privacy, :integer, :default => 1
  end
end

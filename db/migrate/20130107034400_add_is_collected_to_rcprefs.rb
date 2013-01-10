class AddIsCollectedToRcprefs < ActiveRecord::Migration
  def change
    add_column :rcprefs, :in_collection, :boolean, :default => true
  end
end

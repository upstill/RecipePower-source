class AddStatusToSites < ActiveRecord::Migration
  def change
    add_column :sites, :approved, :boolean
    remove_column :sites, :reviewed, :boolean, :default => false
  end
end

class AddStatusToSites < ActiveRecord::Migration[4.2]
  def change
    add_column :sites, :approved, :boolean
    remove_column :sites, :reviewed, :boolean, :default => false
  end
end

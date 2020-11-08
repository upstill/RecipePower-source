class AddTrackablesToSite < ActiveRecord::Migration[5.2]
  def change
    add_column :sites, :logo, :text
    add_column :sites, :name, :text
  end
end

class RenameSiteInSites < ActiveRecord::Migration
  def change
    rename_column :sites, :site, :oldsite
    add_column :sites, :thumbnail_id, :integer
  end
end

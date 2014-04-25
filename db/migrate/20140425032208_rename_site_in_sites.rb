class RenameSiteInSites < ActiveRecord::Migration
  def change
    rename_column :sites, :site, :oldsite
  end
end

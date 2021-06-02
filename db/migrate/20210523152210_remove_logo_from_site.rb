class RemoveLogoFromSite < ActiveRecord::Migration[5.2]
  def change
    remove_column :sites, :logo, :text
  end
end

class AddSiteReferentIdToSite < ActiveRecord::Migration
  def change
    add_column :sites, :referent_id, :integer
  end
end

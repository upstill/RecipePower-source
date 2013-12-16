class AddReviewedToSite < ActiveRecord::Migration
  def change
    add_column :sites, :reviewed, :boolean, default: false
    add_column :sites, :description, :text
    remove_column :sites, :ttlrepl, :string
  end
end

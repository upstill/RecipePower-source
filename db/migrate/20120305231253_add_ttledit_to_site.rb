class AddTtleditToSite < ActiveRecord::Migration
  def change
    add_column :sites, :ttlcut, :string
    add_column :sites, :ttlrepl, :string
  end
end

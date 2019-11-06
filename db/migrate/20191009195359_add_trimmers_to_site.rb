class AddTrimmersToSite < ActiveRecord::Migration[5.1]
  def change
    add_column :sites, :trimmers, :text, :default => [].to_yaml
  end
end

class DropRefUrls < ActiveRecord::Migration
  def up
	remove_column :references, :reference_type
	remove_column :users, :image
	remove_column :recipes, :url
	remove_column :recipes, :picurl
	remove_column :recipes, :href
	remove_column :recipes, :alias
	remove_column :recipes, :thumbnail_id
	remove_column :sites, :logo
	remove_column :sites, :oldsite
	remove_column :sites, :scheme
	remove_column :sites, :host
	remove_column :sites, :port
  end
end

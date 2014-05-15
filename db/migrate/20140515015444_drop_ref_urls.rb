class DropRefUrls < ActiveRecord::Migration
  def up
	remove_column :references, :reference_type
	remove_column :taggings, :is_definition
	remove_column :users, :image
	remove_column :users, :thumbnail_id
	drop_table :thumbnails
	remove_column :recipes, :url
	remove_column :recipes, :picurl
	remove_column :recipes, :tagpane
	remove_column :recipes, :href
	remove_column :recipes, :alias
	remove_column :recipes, :thumbnail_id
	remove_column :sites, :logo
	remove_column :sites, :home
	remove_column :sites, :oldsite
	remove_column :sites, :subsite
	remove_column :sites, :scheme
	remove_column :sites, :host
	remove_column :sites, :port
  end
end

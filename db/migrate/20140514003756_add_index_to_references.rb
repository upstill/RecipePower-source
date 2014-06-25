class AddIndexToReferences < ActiveRecord::Migration
  def up
	change_column :references, :type, :string, :limit => 25, :default => "Reference"
	add_index(:references, [:url, :type], unique: true, using: 'btree', name: "references_index_by_url_and_type") unless index_name_exists?(:references, "references_index_by_url_and_type", false)
	add_index(:references, [:affiliate_id, :type], name: "references_index_by_affil_and_type") unless index_name_exists?(:references, "references_index_by_affil_and_type", false)
	add_index(:recipes, :title, name: "recipes_index_by_title") unless index_name_exists?(:recipes, "recipe_index_by_id", false)
	add_index(:recipes, :id, unique: true, name: "recipes_index_by_id") unless index_name_exists?(:recipes, "recipes_index_by_id", false)
	add_index(:tags, :id, unique: true, name: "tags_index_by_id") unless index_name_exists?(:tags, "tags_index_by_id", false)
	add_index(:sites, :id, unique: true, name: "sites_index_by_id") unless index_name_exists?(:sites, "sites_index_by_id", false)
	add_index(:references, :id, unique: true, name: "references_index_by_id") unless index_name_exists?(:references, "references_index_by_id", false)
   	remove_index(:taggings, :name => :tagging_unique) if index_name_exists?(:taggings, :tagging_unique, false)
  end

  def down
   change_column :references, :type, :string, :default => "Reference"
   remove_index(:references, name: "references_index_by_url_and_type") if index_name_exists?(:references, "references_index_by_url_and_type", false)
   remove_index(:references, name: "references_index_by_affil_and_type") if index_name_exists?(:references, "references_index_by_affil_and_type", false)
   remove_index(:recipes, name: "recipes_index_by_title") if index_name_exists?(:recipes, "recipes_index_by_title", false)
   remove_index(:recipes, name: "recipes_index_by_id") if index_name_exists?(:recipes, "recipes_index_by_id", false)
   remove_index(:tags, name: "tags_index_by_id") if index_name_exists?(:tags, "tags_index_by_id", false)
   remove_index(:sites, name: "sites_index_by_id") if index_name_exists?(:sites, "sites_index_by_id", false)
   remove_index(:references, name: "references_index_by_id") if index_name_exists?(:references, "references_index_by_id", false)
   add_index(:taggings, [:user_id, :tag_id, :entity_id, :entity_type, :is_definition], :unique => true, :name => :tagging_unique) if index_name_exists?(:taggings, [:user_id, :tag_id, :entity_id, :entity_type, :is_definition], false)
  end

end

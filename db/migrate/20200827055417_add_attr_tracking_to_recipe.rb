class AddAttrTrackingToRecipe < ActiveRecord::Migration[5.2]
  def change
    remove_column :gleanings, :needs, :text, array: true, default: []
    add_column :recipes, :attr_trackers, :integer, default: 0
    add_column :page_refs, :attr_trackers, :integer, default: 0
    add_column :mercury_results, :attr_trackers, :integer, default: 0
    add_column :gleanings, :attr_trackers, :integer, default: 0
    add_column :recipe_pages, :attr_trackers, :integer, default: 0
    add_column :sites, :attr_trackers, :integer, default: 0
    add_column :image_references, :attr_trackers, :integer, default: 0
    add_column :scrapers, :attr_trackers, :integer, default: 0
  end
end

class AddAttrTrackingToRecipe < ActiveRecord::Migration[5.2]
  def change
    remove_column :gleanings, :needs, :text, array: true, default: []
    add_column :recipes, :attr_tracking, :integer, default: 0
    add_column :page_refs, :attr_tracking, :integer, default: 0
    add_column :mercury_results, :attr_tracking, :integer, default: 0
    add_column :gleanings, :attr_tracking, :integer, default: 0
    add_column :recipe_pages, :attr_tracking, :integer, default: 0
  end
end

class AddRecipeIdToFeedEntry < ActiveRecord::Migration
  def change
    add_column :feed_entries, :recipe_id, :integer
  end
end

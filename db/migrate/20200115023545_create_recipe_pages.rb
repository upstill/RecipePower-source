class CreateRecipePages < ActiveRecord::Migration[5.2]
  def change
    unless ActiveRecord::Base.connection.table_exists?("recipe_pages")
        create_table :recipe_pages do |t|
          t.text :content, default: ''

          # For processing in background
          t.integer :status, default: 0
          t.integer :dj_id

          t.timestamps
        end
    end

    # RecipePages are accessed through the associated PageRef
    add_column :page_refs, :recipe_page_id, :integer
  end
end

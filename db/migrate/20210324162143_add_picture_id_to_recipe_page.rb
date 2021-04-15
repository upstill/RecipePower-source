class AddPictureIdToRecipePage < ActiveRecord::Migration[5.2]
  def up
    add_column :recipe_pages, :picture_id, :integer
    add_column :recipe_pages, :page_ref_id, :integer
    add_column :recipe_pages, :title, :string
    # Move the id field linking a PageRef and a RecipePage to the RecipePage
    PageRef.where.not(recipe_page_id: nil).pluck(:id, :recipe_page_id).each do |prid, rpid|
      rp = RecipePage.find(rpid) 
      rp.update_attribute :page_ref_id, prid
    end
    rename_column :page_refs, :recipe_page_id, :old_recipe_page_id
  end

  def down
    remove_column :recipe_pages, :picture_id, :integer
    remove_column :recipe_pages, :page_ref_id, :integer
    remove_column :recipe_pages, :title, :string
    rename_column :page_refs, :old_recipe_page_id, :recipe_page_id
  end
end

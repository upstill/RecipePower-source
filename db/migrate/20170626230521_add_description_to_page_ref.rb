class AddDescriptionToPageRef < ActiveRecord::Migration[4.2]
  def change
    add_column :page_refs, :description, :text
  end
end

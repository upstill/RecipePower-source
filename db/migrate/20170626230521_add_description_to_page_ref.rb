class AddDescriptionToPageRef < ActiveRecord::Migration
  def change
    add_column :page_refs, :description, :text
  end
end

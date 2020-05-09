class RemoveContentFromPageRef < ActiveRecord::Migration[5.1]
  def change
    remove_column :page_refs, :content, :text
  end
end

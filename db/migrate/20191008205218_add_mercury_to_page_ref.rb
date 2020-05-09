class AddMercuryToPageRef < ActiveRecord::Migration[5.1]
  def change
    add_column :page_refs, :mercury_results, :text, :default => {}.to_yaml
  end
end

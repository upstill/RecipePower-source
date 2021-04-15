class RemoveContentFromMercuryResult < ActiveRecord::Migration[5.2]
  def change
	remove_column :mercury_results, :content, :text
  end
end

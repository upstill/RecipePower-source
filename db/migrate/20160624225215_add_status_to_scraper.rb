class AddStatusToScraper < ActiveRecord::Migration[4.2]
  def change
    add_column :scrapers, :status, :integer, :default => 0
    remove_column :scrapers, :data
  end
end

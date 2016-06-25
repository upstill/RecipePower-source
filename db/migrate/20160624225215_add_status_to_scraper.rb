class AddStatusToScraper < ActiveRecord::Migration
  def change
    add_column :scrapers, :status, :integer, :default => 0
    remove_column :scrapers, :data
  end
end

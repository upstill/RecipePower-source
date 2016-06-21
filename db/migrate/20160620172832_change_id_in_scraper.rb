class ChangeIdInScraper < ActiveRecord::Migration
  def change
    change_column :scrapers, :id, :bigint
  end
end

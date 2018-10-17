class AddErrmsgToScraper < ActiveRecord::Migration
  def change
    add_column :scrapers, :errmsg, :string
  end
end

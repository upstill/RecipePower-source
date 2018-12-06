class AddErrmsgToScraper < ActiveRecord::Migration[4.2]
  def change
    add_column :scrapers, :errmsg, :string
  end
end

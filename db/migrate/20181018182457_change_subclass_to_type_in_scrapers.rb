class ChangeSubclassToTypeInScrapers < ActiveRecord::Migration[4.2]
  def change
	rename_column :scrapers, :subclass, :type
  end
end

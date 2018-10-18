class ChangeSubclassToTypeInScrapers < ActiveRecord::Migration
  def change
	rename_column :scrapers, :subclass, :type
  end
end

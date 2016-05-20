class CreateScrapers < ActiveRecord::Migration
  def change
    create_table :scrapers do |t|
      t.string :page
      t.string :what
      t.string :subclass, default: 'Scraper'
      t.text :data
      t.datetime :run_at
      t.integer :waittime, default: 1
      t.integer :errcode, default: 0

      t.timestamps null: false
    end
  end
end

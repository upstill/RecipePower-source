class CreateScrapers < ActiveRecord::Migration
  def change
    create_table :scrapers, :force => true do |t|
      t.string :url
      t.string :what
      t.string :subclass, default: 'Scraper'
      t.text :data
      t.boolean :recur, default: true
      t.datetime :run_at
      t.integer :waittime, default: 1
      t.integer :errcode, default: 0

      t.timestamps null: false
    end
  end
end

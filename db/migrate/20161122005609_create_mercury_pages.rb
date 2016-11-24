class CreateMercuryPages < ActiveRecord::Migration
  def change
    create_table :mercury_pages do |t|
      t.text :url
      t.text :title
      t.text :content
      t.datetime :date_published
      t.text :lead_image_url
      t.string :domain
      t.string :extraneity, default: '{}'
      t.string :author

      t.timestamps null: false
    end
    add_column :mercury_pages, :aliases, :text, array: true, default: []
    add_index :mercury_pages, :url, :unique => true
  end
end

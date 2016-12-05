class CreatePageRefs < ActiveRecord::Migration
  def change
    create_table :page_refs do |t|
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
    add_column :page_refs, :aliases, :text, array: true, default: []
    add_index :page_refs, :url, :unique => true

    add_column :recipes, :page_ref_id, :integer
  end
end

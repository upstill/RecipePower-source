class CreatePageRefs < ActiveRecord::Migration
  def change
    create_table :page_refs do |t|
      # Data extracted via Mercury
      t.text :url
      t.string :domain
      t.string :link_text # For labeling links

      # Polymorphic
      t.string :type, :limit => 25, :default => "PageRef"

      # For MercuryScannable
      t.text :title
      t.text :content
      t.datetime :date_published
      t.text :lead_image_url
      t.string :extraneity, default: '{}'
      t.string :author

      # For images
      # t.text :thumbdata

      # For Delayed_Job processing
      t.integer :errcode
      t.integer :status, default: 0
      t.integer :dj_id

      t.timestamps null: false
    end
    add_column :page_refs, :aliases, :text, array: true, default: []
    # add_index :page_refs, :url, :unique => true
    add_index :page_refs, [:url, :type], unique: true, using: 'btree', name: "page_refs_index_by_url_and_type"
    # add_index  :page_refs, :aliases, using: 'gin' # Doesn't seem to work

    add_column :recipes, :page_ref_id, :integer
    add_column :sites, :page_ref_id, :integer
  end
end

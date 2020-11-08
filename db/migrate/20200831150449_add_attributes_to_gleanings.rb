class AddAttributesToGleanings < ActiveRecord::Migration[5.2]
  def change
    add_column :gleanings, :url, :text
    add_column :gleanings, :picurl, :text
    add_column :gleanings, :title, :text
    add_column :gleanings, :author, :text
    add_column :gleanings, :author_link, :text
    add_column :gleanings, :description, :text
    add_column :gleanings, :tags, :text
    add_column :gleanings, :site_name, :string
    add_column :gleanings, :rss_feed, :text
    add_column :gleanings, :content, :text
  end
end

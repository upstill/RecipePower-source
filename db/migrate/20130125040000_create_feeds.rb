class CreateFeeds < ActiveRecord::Migration
  def change
    create_table :feeds do |t|
      t.text :url
      t.integer :feedtype, :default => 0
      t.string :description
      t.integer :site_id
      t.boolean :approved

      t.timestamps
    end
  end
end

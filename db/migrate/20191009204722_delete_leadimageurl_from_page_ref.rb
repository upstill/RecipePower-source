class DeleteLeadimageurlFromPageRef < ActiveRecord::Migration[5.1]
  def up
	remove_column :page_refs, :lead_image_url
	remove_column :page_refs, :extraneity
  end
  def down
	add_column :page_refs, :lead_image_url, :text
	add_column :page_refs, :extraneity, :text, default: {}.to_yaml
  end
end

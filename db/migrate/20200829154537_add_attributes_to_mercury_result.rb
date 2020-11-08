class AddAttributesToMercuryResult < ActiveRecord::Migration[5.2]
  def change
    add_column :mercury_results, :title, :text
    add_column :mercury_results, :author, :text
    add_column :mercury_results, :date_published, :datetime
    add_column :mercury_results, :lead_image_url, :text
    add_column :mercury_results, :content, :text
    add_column :mercury_results, :url, :text
    add_column :mercury_results, :domain, :text
    add_column :mercury_results, :excerpt, :text
    add_column :mercury_results, :mercury_error, :text
  end
end

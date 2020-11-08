class ChangeExcerptInMercuryResults < ActiveRecord::Migration[5.2]
  def change
    rename_column :mercury_results, :excerpt, :description
    rename_column :mercury_results, :lead_image_url, :picurl
    add_column :mercury_results, :new_aliases, :text, array: true, default: []
  end
end

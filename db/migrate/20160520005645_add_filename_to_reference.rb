class AddFilenameToReference < ActiveRecord::Migration[4.2]
  def change
    add_column :references, :filename, :string
    add_column :references, :link_text, :string
  end
end

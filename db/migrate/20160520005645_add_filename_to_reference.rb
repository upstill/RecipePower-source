class AddFilenameToReference < ActiveRecord::Migration
  def change
    add_column :references, :filename, :string
    add_column :references, :link_text, :string
  end
end

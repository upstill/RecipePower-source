class AddFilenameToReference < ActiveRecord::Migration
  def change
    add_column :references, :filename, :string
  end
end

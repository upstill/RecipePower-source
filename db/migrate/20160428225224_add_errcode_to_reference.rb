class AddErrcodeToReference < ActiveRecord::Migration[4.2]
  def change
    rename_column :references, :status, :errcode
    add_column :references, :status, :integer, :default => 0
  end
end

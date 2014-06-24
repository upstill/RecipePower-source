class AddThumbdataToReference < ActiveRecord::Migration
  def change
    change_column :references, :url, :text
    add_column :references, :affiliate_id, :integer
    add_column :references, :type, :string, default: "Reference"
    add_column :references, :thumbdata, :text
    add_column :references, :status, :integer
    add_column :references, :canonical, :boolean, default: false
  end
end

class AddTypeToReference < ActiveRecord::Migration
  def change
    add_column :references, :type, :string, default: "Reference"
    add_column :references, :picurl, :text
    add_column :references, :thumbnail_id, :integer
  end
end

class AddTypeToReferences < ActiveRecord::Migration
  def change
    add_column :references, :reference_type, :integer
    add_column :references, :url, :string
  end
end

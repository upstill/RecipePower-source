class AddTypeToReferences < ActiveRecord::Migration
  def change
    add_column :references, :reference_type, :integer
  end
end

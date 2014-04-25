class AddThumbdataToReferences < ActiveRecord::Migration
  def change
    add_column :references, :thumbdata, :text
    add_column :references, :status, :integer
  end
end

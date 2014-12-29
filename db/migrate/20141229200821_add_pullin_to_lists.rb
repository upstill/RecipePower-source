class AddPullinToLists < ActiveRecord::Migration
  def change
    add_column :lists, :pullin, :boolean, default: true
  end
end

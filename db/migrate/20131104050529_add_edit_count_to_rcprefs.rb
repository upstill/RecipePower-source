class AddEditCountToRcprefs < ActiveRecord::Migration
  def change
    add_column :rcprefs, :edit_count, :integer, default: 0
  end
end

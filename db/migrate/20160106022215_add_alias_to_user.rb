class AddAliasToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :alias_id, :integer
  end
end

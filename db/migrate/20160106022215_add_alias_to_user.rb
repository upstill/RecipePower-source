class AddAliasToUser < ActiveRecord::Migration
  def change
    add_column :users, :alias_id, :integer
  end
end

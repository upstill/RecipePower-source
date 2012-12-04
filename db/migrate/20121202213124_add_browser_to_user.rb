class AddBrowserToUser < ActiveRecord::Migration
  def change
    add_column :users, :browser_serialized, :text

  end
end

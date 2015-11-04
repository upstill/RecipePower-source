class DropListsUsers < ActiveRecord::Migration
  def up
	drop_table :lists_users
	drop_table :feeds_users
  end
end

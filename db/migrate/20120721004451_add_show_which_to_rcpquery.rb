class AddShowWhichToRcpquery < ActiveRecord::Migration
  def change
    add_column :rcpqueries, :which_list, :string, :default => "mine"
    remove_column :rcpqueries, :showmine
    remove_column :rcpqueries, :showfriends
    remove_column :rcpqueries, :showchannels
    remove_column :rcpqueries, :showall
  end
end

class AddFieldsToRcpquery < ActiveRecord::Migration
  def change
    add_column :rcpqueries, :showmine, :boolean, :default => true
    add_column :rcpqueries, :showfriends, :boolean, :default => false
    add_column :rcpqueries, :friend_id, :integer, :default => 0
    add_column :rcpqueries, :showchannels, :boolean, :default => false
    add_column :rcpqueries, :channel_id, :integer, :default => 0
    add_column :rcpqueries, :showall, :boolean, :default => false
  end
end

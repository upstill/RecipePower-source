class AddChannelToUsers < ActiveRecord::Migration
  def change
    add_column :users, :channel_referent_id, :integer, :default => 0
  end
end

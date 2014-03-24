class AddPriorityToPrivateSubscriptions < ActiveRecord::Migration
  def change
    add_column :private_subscriptions, :priority, :integer, default: 10
  end
end

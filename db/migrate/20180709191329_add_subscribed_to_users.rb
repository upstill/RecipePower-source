class AddSubscribedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :subscribed, :boolean, default: true
    add_column :users, :last_edition, :integer, default: 0
  end
end

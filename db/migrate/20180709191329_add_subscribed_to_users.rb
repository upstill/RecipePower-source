class AddSubscribedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :subscribed, :boolean, default: true
    add_column :users, :last_edition, :integer, default: 0
    # :status and :dj_id are for Delayed::Job
    add_column :users, :status, :integer, default: 0
    add_column :users, :dj_id, :integer, default: 0
    # add_column :editions, :status, :integer, default: 0
    # add_column :editions, :dj_id, :integer, default: 0
  end
end

class AddNicknameToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :fullname, :string, :default=>""
    add_column :users, :image, :string, :default=>""
    add_column :users, :about, :text, :default=>""
    change_column :users, :role_id, :integer, :default => 2
  end
  def self.down
    remove_column :users, :fullname
    remove_column :users, :image
    remove_column :users, :about
    change_column :users, :role_id, :integer, :default => 0
  end

end

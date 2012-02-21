class RemoveUserIdFromTags < ActiveRecord::Migration
  def up
     remove_column :tags, :user_id
     remove_column :tags, :parent_id
  end

  def down
     add_column :tags, :user_id, :integer
     add_column :tags, :parent_id, :integer
  end
end

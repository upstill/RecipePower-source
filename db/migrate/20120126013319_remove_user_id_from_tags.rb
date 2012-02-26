class RemoveUserIdFromTags < ActiveRecord::Migration
  def up
     remove_column :tags, :user_id
  end

  def down
     add_column :tags, :user_id, :integer
  end
end

class AddThumnailIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :thumbnail_id, :integer
  end
end

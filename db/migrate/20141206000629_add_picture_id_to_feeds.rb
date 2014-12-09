class AddPictureIdToFeeds < ActiveRecord::Migration
  def change
    add_column :feeds, :picture_id, :integer
    add_column :products, :picture_id, :integer
    rp = User.find(User.super_id)
    rp.username = "RecipePower"
    rp.save
  end
end

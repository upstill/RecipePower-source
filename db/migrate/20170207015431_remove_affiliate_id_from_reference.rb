class RemoveAffiliateIdFromReference < ActiveRecord::Migration
  def change
    remove_column :references, :affiliate_id, :integer
  end
end

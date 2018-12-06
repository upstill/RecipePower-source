class RemoveAffiliateIdFromReference < ActiveRecord::Migration[4.2]
  def change
    remove_column :references, :affiliate_id, :integer
  end
end

class CreateFeedsUsers < ActiveRecord::Migration
  def change
    create_table :feeds_users do |t|
      t.integer :feed_id
      t.integer :user_id
    end
  end
end

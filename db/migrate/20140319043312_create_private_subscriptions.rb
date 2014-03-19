class CreatePrivateSubscriptions < ActiveRecord::Migration
  def change
    create_table :private_subscriptions do |t|
      t.integer :user_id
      t.integer :tag_id

      t.timestamps
    end
  end
end

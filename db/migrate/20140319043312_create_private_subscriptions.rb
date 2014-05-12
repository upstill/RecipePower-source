class CreatePrivateSubscriptions < ActiveRecord::Migration
  def up
    unless ActiveRecord::Base.connection.table_exists?("private_subscriptions")
      create_table :private_subscriptions do |t|
        t.integer :user_id
        t.integer :tag_id
        t.integer :priority, default: 10
  
        t.timestamps
      end
    end
  end

  def down
    drop_table :private_subscriptions
  end
end

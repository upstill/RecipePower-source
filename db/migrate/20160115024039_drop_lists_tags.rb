class DropListsTags < ActiveRecord::Migration[4.2]
  def up
	drop_table :lists_tags
	drop_table :private_subscriptions
	drop_table :channels_referents
  end
end

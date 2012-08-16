class CreateChannelsReferents < ActiveRecord::Migration
    def change
      create_table :channels_referents, :id => false do |t|
        t.integer :channel_id
        t.integer :referent_id
      end
    end
end

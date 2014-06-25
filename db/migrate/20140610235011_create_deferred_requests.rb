class CreateDeferredRequests < ActiveRecord::Migration
  def change
    create_table :deferred_requests do |t|
      t.text :requests

      t.timestamps
    end
  end
end

class RemoveRcpquery < ActiveRecord::Migration
  def up
    if ActiveRecord::Base.connection.table_exists?("rcpqueries")
      drop_table :rcpqueries 
      remove_column :ratings, :rcpquery_id
    end
  end
end

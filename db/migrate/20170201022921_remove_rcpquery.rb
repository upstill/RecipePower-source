class RemoveRcpquery < ActiveRecord::Migration[4.2]
  def up
    if ActiveRecord::Base.connection.table_exists?("rcpqueries")
      drop_table :rcpqueries 
      remove_column :ratings, :rcpquery_id
    end
  end
end

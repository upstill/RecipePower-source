class RemoveRatingstxtFromRcpquery < ActiveRecord::Migration
  def up
      remove_column :rcpqueries, :ratingstxt	
      remove_column :rcpqueries, :fromsitestxt	
      remove_column :rcpqueries, :statustxt	
      remove_column :rcpqueries, :circlestxt	
      remove_column :rcpqueries, :querytext	
      remove_column :rcpqueries, :querymode	
      add_column :rcpqueries, :specialtags, :text
  end

  def down
      remove_column :rcpqueries, :specialtags
      add_column :rcpqueries, :ratingstxt, :text	
      add_column :rcpqueries, :fromsitestxt, :text	
      add_column :rcpqueries, :statustxt, :string	
      add_column :rcpqueries, :circlestxt, :text	
      add_column :rcpqueries, :querytext, :text	
      add_column :rcpqueries, :querymode, :string	
  end
end

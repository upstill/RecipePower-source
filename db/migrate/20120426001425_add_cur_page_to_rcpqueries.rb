class AddCurPageToRcpqueries < ActiveRecord::Migration
  def change
    add_column :rcpqueries, :cur_page, :integer, :default => 1
  end
end

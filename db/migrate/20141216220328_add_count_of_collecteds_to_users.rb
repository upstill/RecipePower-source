class AddCountOfCollectedsToUsers < ActiveRecord::Migration
  def up
    add_column :users, :count_of_collecteds, :integer, :null => false, :default => 0
    # Rcpref.counter_culture_fix_counts
  end

  def down
    remove_column :users, :count_of_collecteds
  end

end

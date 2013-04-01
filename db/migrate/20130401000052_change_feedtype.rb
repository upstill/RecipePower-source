class ChangeFeedtype < ActiveRecord::Migration
  def up
    change_column :feeds, :feedtype, :integer, :default => 0
  end

  def down
    change_column :feeds, :feedtype, :integer, :default => 1
  end
end

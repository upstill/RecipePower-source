class ChangeSampleInSite < ActiveRecord::Migration
  def up
	change_column :sites, :sample, :text
  end

  def down
        change_column :sites, :sample, :string
  end
end

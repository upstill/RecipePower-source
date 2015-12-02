class AddFeedsCountToSites < ActiveRecord::Migration
  def up
    add_column :sites, :feeds_count, :integer, :default => 0
    add_column :sites, :approved_feeds_count, :integer, :default => 0
    Site.find_each do |site|
      if (site.feeds_count = site.feeds.count) > 0
        site.approved_feeds_count = site.feeds.where(approved: true).count
        site.save
      end
    end
  end

  def down
    remove_column :sites, :feeds_count
    remove_column :sites, :approved_feeds_count
  end

end

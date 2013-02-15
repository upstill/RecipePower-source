class AddTitleToFeeds < ActiveRecord::Migration
  def up
    add_column :feeds, :title, :string
    change_column :feeds, :feedtype, :integer, :default => 1	
    Feed.all.each { |feed|
      begin
        feed.follow_url
        unless feed.save
          feed.destroy
        end
      rescue Exception => e
        feed.destroy
      end
    }
  end

  def down
    remove_column :feeds, :title
  end
end

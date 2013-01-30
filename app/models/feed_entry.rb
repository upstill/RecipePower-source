class FeedEntry < ActiveRecord::Base
  attr_accessible :guid, :name, :published_at, :summary, :url
end

class FeedEntry < ActiveRecord::Base
  include Taggable
  attr_accessible :guid, :name, :published_at, :summary, :url, :feed, :recipe
  
  belongs_to :feed
  belongs_to :recipe
  
  def self.update_from_feed(feed)
    feedz = Feedzirra::Feed.fetch_and_parse(feed.url)
    add_entries(feedz.entries, feed) if feedz.respond_to? :entries
  end
  
  def self.update_from_feed_continuously(feed, delay_interval = 1.day)
    feedz = Feedzirra::Feed.fetch_and_parse(feed.url)
    add_entries(feedz.entries, feed)
    loop do
      sleep delay_interval
      feedz = Feedzirra::Feed.update(feedz)
      add_entries(feedz.new_entries, feed) if feedz.updated?
    end
  end
  
  private
  
  def self.add_entries(entries, feed)
    entries.each do |entry|
      entry.published = Time.current unless entry.published
      unless exists? :guid => entry.id
        create!(
          :name         => entry.title,
          :summary      => entry.summary,
          :url          => entry.url,
          :published_at => entry.published,
          :guid         => entry.id,
          :feed         => feed
        )
      end
    end
  end
end

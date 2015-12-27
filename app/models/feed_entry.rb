class FeedEntry < ActiveRecord::Base
  include Collectible
  picable :picurl, :picture

  attr_accessible :guid, :title, :published_at, :summary, :url, :feed, :recipe

  belongs_to :recipe
  belongs_to :feed, :counter_cache => true
  delegate :site, :to => :feed

  # Return scopes for searching the title and description
  def self.strscopes matcher
    scope = block_given? ? yield() : self.unscoped
    [
        scope.where('"feed_entries"."title" ILIKE ?', matcher),
        scope.where('"feed_entries"."summary" ILIKE ?', matcher)
    ]
  end

  def self.update_from_feed(feed)
    feedz = Feedjira::Feed.fetch_and_parse(feed.url)
    add_entries(feedz.entries, feed) if feedz.respond_to? :entries
  end
  
  def self.update_from_feed_continuously(feed, delay_interval = 1.day)
    feedz = Feedjira::Feed.fetch_and_parse(feed.url)
    add_entries(feedz.entries, feed)
    loop do
      sleep delay_interval
      feedz = Feedjira::Feed.update(feedz)
      add_entries(feedz.new_entries, feed) if feedz.updated?
    end
  end

  private
  
  def self.add_entries(entries, feed)
    last_posted =
    entries.map { |entry|
      unless exists? :guid => entry.id
        entry.published ||= Time.current
        create!(
          :title        => entry.title,
          :summary      => entry.summary,
          :url          => entry.url,
          :published_at => entry.published,
          :guid         => entry.id,
          :feed         => feed
        )
        entry.published
      end
    }.compact.sort.last
    # Update the last_post_date of the feed if there's a new entry
    if last_posted && (feed.last_post_date.nil? || (last_posted > feed.last_post_date))
      feed.last_post_date = last_posted
      feed.save
    end
  end
end

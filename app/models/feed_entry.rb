class FeedEntry < ApplicationRecord
  include Taggable # Can be tagged using the Tagging model
  include Collectible
  picable :picurl, :picture

  # attr_accessible :guid, :title, :published_at, :summary, :url, :feed, :recipe

  if Rails::VERSION::STRING[0].to_i < 5
    belongs_to :recipe
  else
    belongs_to :recipe, :optional => true
  end
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
    # Identify the guids of entries that already exist
    existing_guids = feed.feed_entries.where(guid: (entries.map &:id)).pluck(:guid)
    # We keep a post_time to provide a default published_at date that correctly orders the entries by guid
    post_time = Time.current
    return unless last_posted =
    entries.sort_by(&:entry_id).reverse.map { |entry|
      unless existing_guids.include?(entry.id) # Create a new entry only if its guid doesn't already exist
        if !(published = entry.published) || (published > Time.current) # No post-dated post dates
          published = post_time
          post_time -= 1.second
        end
        create!(
          :title        => entry.title,
          :summary      => entry.summary,
          :url          => entry.url,
          :published_at => published,
          :guid         => entry.id,
          :feed         => feed
        )
        published
      end
    }.compact.sort.last
    # Update the last_post_date of the feed if there's a new entry
    last_posted ||= Time.now
    feed.update_column :last_post_date, last_posted if feed.last_post_date.nil? || (last_posted > feed.last_post_date)
  end
end

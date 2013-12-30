require 'feedzirra'

class Feed < ActiveRecord::Base
  include Taggable
  attr_accessible :title, :description, :site_id, :feedtype, :approved, :url
  
  # Setup a feed properly: do a reality check on the url, populate the information
  # fields (title, description...), and ensure it has an associated site
  before_validation { |feed| feed.follow_url if (new_record? || url_changed?) }
  
  belongs_to :site
  validates :site, :presence => true
  validates :url, :presence => true, :uniqueness => true
  
  has_and_belongs_to_many :users
  
  has_many :feed_entries, :dependent => :destroy

  # When a feed is built, the url may be valid for getting to a feed, but it may also
  # alias to the url of an already-extant feed (no good). We also need to extract the title and description 
  # from the feed, but only once. Thus, we "follow" the url once, when a new feed is created
  # or the url changes. 
  def follow_url 
    # First, check out the feed
    if fetch
      self.title = (@fetched.title || "").truncate(255)
      self.description = (@fetched.description || "").truncate(255)
      self.url = @fetched.feed_url unless @fetched.feed_url.blank?
      self.site = Site.by_link (@fetched.url || url)
    end
  end
    
  def self.correct
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
  
  # Return list of feed_entries by id for all feeds in the feedlist
  def self.entry_ids feedlist
    # Feed.find(feedlist).each { |feed| feed.update_entries }
    # We could be fetching individual feeds, then sorting, but we'll just let the database handle that...
    FeedEntry.where(feed_id: feedlist).order('published_at DESC').map(&:id)
  end
  
  # Return list of feed_entries by id for this feed
  def entry_ids
    @idcache ||= begin
      # update_entries
      FeedEntry.where(feed_id: id).order('published_at DESC').map(&:id)
    end
  end
  
  def entries
    @entrycache ||= begin
      # update_entries
      FeedEntry.where(feed_id: id).order('published_at DESC')
    end
  end
  
  # Check all feeds that are approved for feed-through for updates
  def self.update_now
    Feed.where(:approved => true).each { |feed| feed.perform }
  end
  
  def refresh
    # Delayed::Job.enqueue self
  end 
  
  def perform
    logger.debug "[#{Time.now}] Updating feed #{to_s}; approved=#{approved ? 'Y' : 'N'}"
    puts "[#{Time.now}] Updating feed "+to_s
    if feed = Feed.where(id: id).first
      FeedEntry.update_from_feed feed
    end
  end

  def enqueue_update later = false
    Delayed::Job.enqueue self, run_at: (later ? (Time.new.beginning_of_week(:sunday)+1.week) : (Time.now+20))
  end

  def success(job)
    # When the feed is updated successfully, re-queue it for one week hence
    feed = YAML::load(job.handler)
    logger.debug "Updated feed ##{job.id}"
    if feed = Feed.where(id: feed.id).first
      feed.enqueue_update true
      feed.touch
    end
  end

  def to_s
    title+" (#{url})"
  end
  
  # Get the external feed, setting the @fetched instance variable to point thereto
  def fetch
    return @fetched if @fetched
    begin
      @fetched = Feedzirra::Feed.fetch_and_parse(url)
      @fetched = nil if @fetched.class == Fixnum
    rescue Exception => e
      @fetched = nil
    end
    unless @fetched
      self.errors.add :url, "doesn't point to a feed"
    end
    @fetched
  end
  
  def self.evaluate
    prevurl = ""
    feedcount = 0
    File.open("/Users/upstill/dev/rss_rejects3.txt", "w") do |outfile|
      File.open("/Users/upstill/dev/rss_rejects2.txt").each do |line|
        fields = line.split(' ')
        feedurl = fields[0]
        pageurl = fields[2].sub(/\)$/, '')
        if(pageurl != prevurl)
          feedcount = (site = Site.by_link pageurl) ? site.feeds.count : 0
          prevurl = pageurl
        end
        outfile.puts line unless feedcount > 0
      end
    end
  end

=begin
  # feed and entries accessors
  feed.title          # => "Paul Dix Explains Nothing"
  feed.url            # => "http://www.pauldix.net"
  feed.feed_url       # => "http://feeds.feedburner.com/PaulDixExplainsNothing"
  feed.etag           # => "GunxqnEP4NeYhrqq9TyVKTuDnh0"
  feed.last_modified  # => Sat Jan 31 17:58:16 -0500 2009 # it's a Time object

  entry = feed.entries.first
  entry.title      # => "Ruby Http Client Library Performance"
  entry.url        # => "http://www.pauldix.net/2009/01/ruby-http-client-library-performance.html"
  entry.author     # => "Paul Dix"
  entry.summary    # => "..."
  entry.content    # => "..."
  entry.published  # => Thu Jan 29 17:00:19 UTC 2009 # it's a Time object
  entry.categories # => ["...", "..."]
  
  def items
    unless @items
      @items = []
      feed = Feedzirra::Feed.fetch_and_parse(url)
      @items = feed.entries
    end
    @items
  end

  def show
    items.each do |entry|
      puts "Item: <a href='#{entry.url}'>#{entry.title}</a>"
      puts "Published on: #{entry.published}"
      puts "#{entry.summary}"
    end
    nil
  end
=end
  
  @@feedtypes = [
    [:Misc, 0], 
    [:Recipes, 1], 
    [:Tips, 2],
    [:Blog, 3],
    [:News, 4]
  ]
  
  @@feedtypenames = []
  @@feedtypes.each { |feedtype| @@feedtypenames[feedtype[1]] = feedtype[0] }

  # return an array of status/value pairs for passing to select()
  def self.feedtype_selection
    @@feedtypes
  end
  
  def feedtypename
    @@feedtypenames[feedtype]
  end
  
end


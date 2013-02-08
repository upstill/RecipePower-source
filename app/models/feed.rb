require 'feedzirra'

class Feed < ActiveRecord::Base
  attr_accessible :description, :site_id, :feedtype, :approved, :url
  
  # Ensure a feed has an associated site (meanwhile confirming that its feed is valid)
  before_validation :ensure_site
  belongs_to :site
  validates :site, :presence => true
  
  has_and_belongs_to_many :users
  
  has_many :feed_entries
  
  # Return list of feed_entries by id for this feed
  def entry_ids
    @idcache ||= begin
      update_entries
      FeedEntry.where(feed_id: id).order('published_at DESC')
    end
  end
  
  def entries
    @entrycache ||= begin
      update_entries
      FeedEntry.where(feed_id: id).order('published_at DESC')
    end
  end
  
  # Return list of feed_entries by id for all feeds in the feedlist
  def self.entry_ids feedlist
    @@idcache ||= begin
      Feed.find(feedlist).each { |feed| feed.update_entries }
      # We could be fetching individual feeds, then sorting, but we'll just let the database handle that...
      FeedEntry.where(feed_id: feedlist).order('published_at DESC').map(&:id)
    end
  end
  
  def update_entries
    if ((Time.now - updated_at) > 900) || feed_entries.empty? # Update at most every 15 minutes
      FeedEntry.update_from_feed self
      touch
    end
  end
  
  # Before validating the record, get the site from the URL
  def ensure_site
    if(fetch && (entry = @fetched.entries.first))
      self.site = Site.by_link entry.url
    else
      self.errors.add :url, (@fetched ? "points to a feed with no entries" : "doesn't point to a feed")
    end
  end
  
  # Get the external feed, setting the @fetched instance variable to point thereto
  def fetch
    return @fetched if @fetched
    begin
      @fetched = Feedzirra::Feed.fetch_and_parse(url)
      if @fetched.class == Fixnum
        self.errors << url+" is not the URL of a feed"
        @fetched = nil 
      else
        self.description = @fetched.title unless @fetched.title.blank?
        self.url = @fetched.feed_url unless @fetched.feed_url.blank?
      end
    rescue Exception => e
      @fetched = nil
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
    [:Tips, 2]
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

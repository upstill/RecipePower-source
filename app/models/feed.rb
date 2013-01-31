require 'feedzirra'

class Feed < ActiveRecord::Base
  attr_accessible :description, :site_id, :feedtype, :approved, :url
  
  belongs_to :site
  
  def self.fetch(url)
    begin
      feed = Feedzirra::Feed.fetch_and_parse(url)
      feed = nil if feed.class == Fixnum
    rescue Exception => e
      feed = nil
    end
    feed
  end
  
  def validate
    if feed = Feed.fetch(url)
      self.description = feed.title unless feed.title.blank?
      self.url = feed.feed_url unless feed.feed_url.blank?
    end
    feed != nil
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
  
  def items
    unless @items
      @items = []
      feed = Feedzirra::Feed.fetch_and_parse(url)
      @items = feed.entries
    end
    @items
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
=end

  def show
    items.each do |entry|
      puts "Item: <a href='#{entry.url}'>#{entry.title}</a>"
      puts "Published on: #{entry.published}"
      puts "#{entry.summary}"
    end
    nil
  end
  
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

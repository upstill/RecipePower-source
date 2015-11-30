require 'feedjira'

class Feed < ActiveRecord::Base
  include Collectible
  picable :picurl, :picture
  attr_accessible :title, :description, :site_id, :feedtype, :approved, :url, :last_post_date
  
  # Setup a feed properly: do a reality check on the url, populate the information
  # fields (title, description...), and ensure it has an associated site
  before_validation { |feed|
    feed.follow_url if ((feed.new_record? && feed.url.present?) || feed.url_changed?)
  }

  belongs_to :site
  validates :site, :presence => true
  validates :url, :presence => true, :uniqueness => true

  has_many :feed_entries, -> { order 'published_at DESC' }, :dependent => :destroy

  # When a feed is built, the url may be valid for getting to a feed, but it may also
  # alias to the url of an already-extant feed (no good). We also need to extract the title and description 
  # from the feed, but only once. Thus, we "follow" the url once, when a new feed is created
  # or the url changes. 
  def follow_url 
    # First, check out the feed
    if fetch
      self.title = (@fetched.title || '').truncate(255)
      self.description = (@fetched.description || '').truncate(255)
      self.site ||= Site.find_or_create url
      unless @fetched.feed_url.blank? || (url == @fetched.feed_url)
        # When the URL changes, clear and update the feed entries
        self.url = @fetched.feed_url
        feed_entries.clear
        FeedEntry.update_from_feed self
      end
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

  def self.strscopes matcher
    onscope = block_given? ? yield() : self.unscoped
    [
        onscope.where('"feeds"."title" ILIKE ?', matcher),
        onscope.where('"feeds"."description" ILIKE ?', matcher)

    ] + Site.strscopes(matcher) { |inward=nil|
      joinspec = inward ? {:site => inward} : :site
      block_given? ? yield(joinspec) : self.joins(joinspec)
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

  def to_s
    "#{(title.present? && title) || ('Feed #'+id.to_s)} (#{url})"
  end
  
  # Get the external feed, setting the @fetched instance variable to point thereto
  def fetch
    return @fetched if @fetched
    begin
      @fetched = Feedjira::Feed.fetch_and_parse url, :on_failure => Proc.new { raise "Feedjira error: Can't open feed" }
      @fetched = nil if [Fixnum, Hash].include?(@fetched.class) # || !@fetched.is_a?(Feedjira::Feed)
    rescue Exception => e
      @fetched = nil
    end
    unless @fetched
      self.errors.add :url, "doesn't point to a feed"
    end
    @fetched
  end
  
  def self.evaluate
    prevurl = ''
    feedcount = 0
    File.open("/Users/upstill/dev/rss_rejects3.txt", "w") do |outfile|
      File.open("/Users/upstill/dev/rss_rejects2.txt").each do |line|
        fields = line.split(' ')
        feedurl = fields[0]
        pageurl = fields[2].sub(/\)$/, '')
        if(pageurl != prevurl)
          feedcount = (site = Site.find_or_create pageurl) ? site.feeds.count : 0
          prevurl = pageurl
        end
        outfile.puts line unless feedcount > 0
      end
    end
  end

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

  def discreet_save
    Feed.record_timestamps = false
    save
    Feed.record_timestamps = true
  end

  # Ensure that the entries for the feed are up to date
  def refresh
    FeedEntry.update_from_feed self
    self.reload # To ensure associations are updated
    self.touch
  end

  # Is the feed stale?
  def due_for_update
    updated_at < 7.days.ago
  end

  # Callbacks for DelayedJob
  def enqueue(job)
    self.status = :pending
    discreet_save
  end

  def before(job)
    self.status = :running
    discreet_save
  end

  def perform
    logger.debug "[#{Time.now}] Updating feed #{id}; approved=#{approved ? 'Y' : 'N'}"
    if feed = Feed.where(id: id).first
      feed.refresh
    end
  end

  def enqueue_update later = false
    Delayed::Job.enqueue self, priority: 10, run_at: (later ? (Time.new.beginning_of_week(:sunday)+1.week) : Time.now)
  end

  def success(job)
    # When the feed is updated successfully, re-queue it for one week hence
    feed = YAML::load(job.handler)
    logger.debug "Successfully updated feed ##{feed.id}"
    if feed = Feed.where(id: feed.id).first
      feed.enqueue_update true
      logger.debug "Queued up feed ##{feed.id}"
      feed.status = :ready
      feed.discreet_save
    end
  end

  def error(job, exception)
    self.status = :failed
    discreet_save
  end

  def failure(job)
    self.status = :failed
    discreet_save
  end
end


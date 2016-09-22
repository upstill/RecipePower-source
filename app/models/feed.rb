require 'feedjira'

class Feed < ActiveRecord::Base
  include Collectible
  include Backgroundable

  backgroundable :status

  picable :picurl, :picture
  attr_accessible :title, :description, :site_id, :feedtype, :approved, :url, :last_post_date
  
  # Setup a feed properly: do a reality check on the url, populate the information
  # fields (title, description...), and ensure it has an associated site
  before_validation { |feed|
    if ((feed.new_record? && feed.url.present?) || feed.url_changed?)
      feed.follow_url
    else
      true
    end
  }

  after_save { |feed|
    if feed.approved_changed?
      site = feed.site
      site.feeds_count = site.feeds.count
      site.approved_feeds_count = site.feeds.where(approved: true).count
      site.save
    end
  }

  belongs_to :site
  validates :site, :presence => true
  validates :url, :presence => true, :uniqueness => true

  has_many :feed_entries, -> { order 'published_at DESC' }, :dependent => :destroy

  def self.fix_counters
    Feed.find_each { |feed| Feed.reset_counters(feed.id, :feed_entries) }
  end

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
    else
      false
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

  def self.preload url
    begin
      f = Feedjira::Feed.fetch_and_parse url, :on_failure => Proc.new { raise 'Feedjira error: Can\'t open feed' }
      f = nil if [Fixnum, Hash].include?(f.class) # || !@fetched.is_a?(Feedjira::Feed)
    rescue Exception => e
      f = nil
    end
    f
  end
  
  # Get the external feed, setting the @fetched instance variable to point thereto
  def fetch
    return @fetched if @fetched
    unless @fetched = Feed.preload(url)
      self.errors.add :url, 'doesn\'t point to a feed'
    end
    @fetched
  end
  
  def self.evaluate
    prevurl = ''
    feedcount = 0
    File.open('/Users/upstill/dev/rss_rejects3.txt', 'w') do |outfile|
      File.open('/Users/upstill/dev/rss_rejects2.txt').each do |line|
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

  # The updated_at timestamp will denote when the feed entries were last updated
  # Thus, saving will not alter the timestamps by default
  alias_method :orig_save, :save

  def hard_save
    self.updated_at = Time.now
    orig_save
  end

  def save
    if updated_at.nil? # Don't violate the non-null constraint on timestamps
      orig_save
    else
      Feed.record_timestamps = false
      orig_save
      Feed.record_timestamps = true
    end
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

  def bkg_enqueue force=false, djopts = {}
    Feed.record_timestamps = false
    super
    Feed.record_timestamps = true
  end

  def perform 
    logger.debug "[#{Time.now}] Updating feed #{id}; approved=#{approved ? 'Y' : 'N'}"
    Feed.record_timestamps = false
    bkg_execute do FeedEntry.update_from_feed(self) || true end
    Feed.record_timestamps = true
    save if good? # Record the last_updated_at time
    good?
  end


  # Launch an update as "necessary"
  def launch_update hard=false
    bkg_enqueue (hard || (updated_at < (Time.now - 1.hour))), priority: 10
  end

  def success(job)
    # When the feed is updated successfully, re-queue it for one week hence
    feed = YAML::load(job.handler)
    logger.debug "Successfully updated feed ##{feed.id}"
=begin
    if feed = Feed.find_by(id: feed.id)
      feed.enqueue_update true
      logger.debug "Queued up feed ##{feed.id}"
    end
=end
  end

end


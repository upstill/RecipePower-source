require 'feedjira'

class Feed < ApplicationRecord
  include Taggable # Can be tagged using the Tagging model
  include Collectible
  include Backgroundable

  backgroundable :status

  picable :picurl, :picture
  # attr_accessible :title, :description, :site_id, :feedtype, :approved, :url, :last_post_date, :home
  
  def self.mass_assignable_attributes
    super + [ :title, :description, :approved, :url, :home ]
  end
  
  # Setup a feed properly: do a reality check on the url, populate the information
  # fields (title, description...), and ensure it has an associated site
  before_validation { |feed|
    if feed.home_changed? && cleanpath(feed.home).present?
      feed.site = Site.find_or_build_for feed.home
    end
    if (feed.new_record? && feed.url.present?) || feed.url_changed?
      feed.follow_url
    else
      true
    end
  }

  after_save { |feed|
    if feed.approved_changed?
      site = feed.site
      site.update_column :feeds_count, site.feeds.count
      site.update_column :approved_feeds_count, site.feeds.where(approved: true).count
    end
    bkg_launch true, run_at: (last_post_date ? 1.week : 1.minute).from_now
  }

  belongs_to :site, :autosave => true
  # validates :site, :presence => true
  validates :url, :presence => true, :uniqueness => true
  # validates_with HomeUrlValidator, fields: [:home]
  validates_each :home, :site do |feed, attr, value|
    case attr
      when :home # Home throws an error if it's a syntactically invalid link
        feed.errors.add :home, "has a bad link (#{value})" if cleanpath(feed.home).blank? && feed.errors[:home].blank?
      when :site
        return unless feed.errors[:site].blank?
        if value
          # If the home link is nominally good, we assume that site errors come from that
          err_source = cleanpath(feed.home).blank? ? :site : :home
          if site_pr = value.page_ref
            site_pr.bkg_land
            if site_pr.good?
              value.save if value.new_record?
              feed.errors.add err_source, "isn't legit (#{value.errors.messages})" if value.errors.present?
            else
              feed.errors.add err_source, "isn't legit (can't access the home page)"
            end
          else
            feed.errors.add err_source, "isn't legit (has no accessible home)"
          end
        else
          feed.errors.add :site, "can't be empty"
        end
    end if feed.home_changed? && feed.home.present?
  end

  has_many :feed_entries, :dependent => :destroy

  # When a feed is built, the url may be valid for getting to a feed, but it may also
  # alias to the url of an already-extant feed (no good). We also need to extract the title and description 
  # from the feed, but only once. Thus, we "follow" the url once, when a new feed is created
  # or the url changes. 
  def follow_url 
    # First, check out the feed
    if fetch
      self.title = (@fetched.title || '').truncate(255)
      self.description = (@fetched.description || '').truncate(255)
      self.site ||= Site.find_or_build_for url
      unless @fetched.feed_url.blank? || (url == @fetched.feed_url)
        # When the URL changes, clear and update the feed entries
        self.url = @fetched.feed_url
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

  def entries_since date
    feed_entries.where 'published_at > ?', (date || Time.now)
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
=begin
      NB: may be able to replace this by using Faraday (per https://github.com/feedjira/feedjira/issues/294)
        conn = Faraday.new do |conn|
          conn.request.options.timeout = 20
        end
        response = conn.get(url)
        xml = response.body
        feed = Feedjira::Feed.parse xml
=end
      f = Feedjira::Feed.fetch_and_parse url,
                                         :on_failure => Proc.new { |a, b|
                                           raise 'Feedjira error: Can\'t open feed'
                                         },
                                         :max_redirects => 5
      # :timeout => 8.0
      f = nil if [Integer, Hash].include?(f.class) # || !@fetched.is_a?(Feedjira::Feed)
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

  def save options={}
    if updated_at.nil? # Don't violate the non-null constraint on timestamps
      orig_save options
    else
      Feed.record_timestamps = false
      result = orig_save options
      Feed.record_timestamps = true
      result
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

  def perform 
    logger.debug "[#{Time.now}] Updating feed #{id}; approved=#{approved ? 'Y' : 'N'}"
    begin
      # Update the timestamps only if successful
      Feed.record_timestamps = false
      FeedEntry.update_from_feed self
      Feed.record_timestamps = true
      touch
      reload
    ensure
      Feed.record_timestamps = true
    end
  end

  # Launch an update as "necessary"
  def launch_update hard=false
    bkg_launch hard, priority: 10, run_at: Time.now
  end

  def after
    # When the feed is updated successfully, re-queue it for tomorrow
    super
    logger.debug "Successfully updated feed ##{id}"
    bkg_launch true, run_at: (Time.now + 1.day)  # Launch the next update for tomorrow
    logger.debug "Queued up feed ##{id}"
  end

end


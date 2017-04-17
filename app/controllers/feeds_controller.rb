class FeedsController < CollectibleController

  # GET /feeds
  # GET /feeds.json
  def index
    @active_menu = :feeds
    response_service.title = (params[:access] == 'collected') ? 'My Feeds' : 'Available Feeds'
    smartrender 
  end

  # GET /feeds/1
  # GET /feeds/1.json
  def show
    @active_menu = :feeds
    update_and_decorate
    # This is when we update the feed. When first showing it, we fire off an update job (as appropriate)
    # When it's time to produce results, we sync up the update process
    smartrender
  end

  def contents
    @active_menu = :feeds
    if update_and_decorate
=begin
      if params[:content_mode] && (params[:content_mode] == 'results')
        @feed.bkg_sync
      else # Don't bother if the last update came in in the last hour
        @feed.launch_update (updated_at < Time.now - 1.hour) # Set a job running to update the feed, as necessary
      end
=end
      if params[:last_entry_id] # Only return entries that have been gathered since this one
        since = (fe = FeedEntry.find_by(id: params[:last_entry_id])) ?
            (fe.published_at+1.second) :
            Time.new(2000)
        list_entries = @feed.feed_entries.exists?(published_at: since..Time.now)
      else
        list_entries = true
      end
      if resource_errors_to_flash @feed
        render :errors
      elsif list_entries
        smartrender
      else
        # Notify of no new entries
        render 'contents_finished'
      end
    end
  end

  def edit
    @active_menu = :feeds
    update_and_decorate
    smartrender
  end

  # GET /feeds/new
  # GET /feeds/new.json
  def new
    @feed = Feed.new
    # update_and_decorate
    response_service.title = 'Open a feed'
    smartrender mode: :modal
  end

  # POST /feeds
  # POST /feeds.json
  def create
    if current_user
      update_and_decorate Feed.find_by(url: params[:feed][:url]) # Builds new one if doesn't already exist
      # URLs uniquely identify feeds, so we may have clashed with an existing one.
      # If so, simply adopt that one.
      if resource_errors_to_flash @feed
        render :new, mode: :modal
      else
        # No problems. Collect the feed now.
        @feed.be_collected
        @feed.save
        if resource_errors_to_flash(@feed)
          render :errors
        else
          flash[:popup] = "'#{@feed.title.truncate(50)}' now appearing in your collection."
          redirect_to feeds_path(access: 'collected') if params[:to_feeds]
        end
      end
    else
      flash[:alert] = 'Sorry, you need to be logged in to add a feed.'
      render :errors
    end
  end

  def refresh
    update_and_decorate
    n_before = @feed.feed_entries_count
    @feed.bkg_go true
    if @feed.good?
      if resource_errors_to_flash(@feed)
        render :errors
      else
        n_new = @feed.feed_entries_count - n_before
        flash[:popup] = labelled_quantity(n_new, 'New entry')+' found'
        render :refresh, locals: {followup: (n_new > 0)}
      end
    else
      flash[:popup] = 'Feed update is still in process'
      render :errors
    end
  end

end

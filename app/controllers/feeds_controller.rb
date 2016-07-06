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
    smartrender
  end

  def contents
    @active_menu = :feeds
    if update_and_decorate
      if params[:last_entry_id] # Only return entries that have been gathered since this one
        @feed.bkg_sync
        since = (fe = FeedEntry.find_by(id: params[:last_entry_id])) ?
            (fe.published_at+1.second) :
            Time.new(2000)
        list_entries = @feed.feed_entries.exists?(published_at: since..Time.now)
      else
        @feed.bkg_requeue if @feed.updated_at < Time.now - 1.minute # Ensure there's an update pending
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
      update_and_decorate Feed.where(url: params[:feed][:url]).first # Builds new one if doesn't already exist
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
    @feed.bkg_sync
    if @feed.good?
      if resource_errors_to_flash(@feed)
        render :errors
      else
        flash[:popup] = labelled_quantity(n_new, 'New entry')+' found'
        render :refresh, locals: {followup: (n_new > 0)}
      end
    else
      flash[:popup] = 'Feed update is still in process'
      render :errors
    end
  end

end

class FeedsController < CollectibleController
  before_action :login_required, :except => [:touch, :index, :show, :associated, :capture, :contents, :card, :collect ]

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
    @replacements = [ view_context.feed_menu_entry_replacement(@feed) ]
    smartrender
  end

  def contents
    @active_menu = :feeds
    if update_and_decorate
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
        current_user.collect @feed
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
    @feed.bkg_launch true # Make sure it's queued up
    @feed.bkg_land true # Force it to run
    if @feed.good?
      if resource_errors_to_flash(@feed)
        render :errors
      else
        n_new = @feed.feed_entries_count - n_before
        flash[:popup] = labelled_quantity(n_new, 'New entry')+' found'
        respond_to do |format|
          format.html { redirect_to contents_feed_path(@feed) }
          format.json { render :refresh, locals: {followup: (n_new > 0)} }
        end
      end
    else
      flash[:popup] = 'Feed update is still in process'
      render :errors
    end
  end

  def rate
    @feed = Feed.find_by id: params[:id]
    new_hotness = params[:hotness].try :to_i
    if new_hotness >= 0 && new_hotness <= 5
      @feed.update_attribute :hotness, new_hotness
      @feed.update_attribute :updated_at, @feed.updated_at+1.second # Bust the display cache, but only minimally
    else
      flash[:error] = "'#{params[:hotness]}' is not a valid hotness"
    end
  end

end

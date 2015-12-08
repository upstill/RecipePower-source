class FeedsController < CollectibleController
  
  def approve
    update_and_decorate
    @feed.approved = params[:approve] == 'Y'
    @feed.save
    flash[:popup] = 'Feedthrough '+(@feed.approved ? "Approved" : "Blocked")
  end
  
  # GET /feeds
  # GET /feeds.json
  def index
    @active_menu = :feeds
    response_service.title = (params[:access] == "collected") ? "My Feeds" : "Available Feeds"
    smartrender 
  end

  # GET /feeds/1
  # GET /feeds/1.json
  def show
    @active_menu = :feeds
    update_and_decorate
    smartrender
  end

  def owned
    @active_menu = :feeds
    @feed.refresh if update_and_decorate && !params[:stream] && @feed.due_for_update
    if resource_errors_to_flash @feed
      render :errors
    else
      smartrender
    end
  end

  def edit
    @active_menu = :feeds
    update_and_decorate
    smartrender
  end

  def update
    update_and_decorate
    if resource_errors_to_flash @decorator.object
      render :edit
    else
      flash[:popup] = "#{@decorator.human_name} is saved"
      render :update
    end
  end

  # GET /feeds/new
  # GET /feeds/new.json
  def new
    @feed = Feed.new
    # update_and_decorate
    response_service.title = "Open a feed"
    smartrender mode: :modal
  end

  # POST /feeds
  # POST /feeds.json
  def create
    if current_user
      update_and_decorate
      # URLs uniquely identify feeds, so we may have clashed with an existing one.
      # If so, simply adopt that one.
      # NB If so, we merrily ignore the other attributes being provided as parameters--if any
      if @feed.errors.any?
        update_and_decorate( (Feed.where url: @feed.url)[0] || @feed )
      end
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
      flash[:alert] = "Sorry, you need to be logged in to add a feed."
      render :errors
    end
  end

  def refresh
    update_and_decorate
    if @feed.status == "ready"
      # if Rails.env.development? # Immediate refresh
        n_entries = @feed.feed_entries.size
        @feed.refresh
        n_new = @feed.feed_entries.size - n_entries
        if resource_errors_to_flash(@feed)
          render :errors
        else
          flash[:popup] = labelled_quantity(n_new, "New entry")+" found"
          render :update
        end
    else
      flash[:popup] = "Feed update is still in process"
      render :errors
    end
  end

end

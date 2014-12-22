require './lib/controller_utils.rb'

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
    smartrender unless do_stream FeedsCache
  end

  # GET /feeds/1
  # GET /feeds/1.json
  def show
    @active_menu = :feeds
    @feed.refresh if update_and_decorate && !params[:stream] && @feed.due_for_update
    if post_resource_errors @feed
      render :errors
    else
      smartrender unless do_stream FeedCache do |sp|
        sp.item_partial = "feed_entries/show_feed_entry"
        sp.results_partial = "stream_results_items"
      end
    end
  end

  # GET /feeds/new
  # GET /feeds/new.json
  def new
    update_and_decorate
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
      if post_resource_errors @feed
        render :new, status: :unprocessable_entity, mode: :modal
      else
        # No problems. Collect the feed now.
        @feed.add_to_collection current_user.id
        @feed.save
        if post_resource_errors(@feed)
          render :errors
        else
          flash[:popup] = "'#{@feed.title.truncate(50)}' now appearing in your collection."
          redirect_to feeds_path(access: "collected", mode: :partial)
        end
      end
    else
      flash[:alert] = "Sorry, you need to be logged in to get a feed."
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
        if post_resource_errors(@feed)
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

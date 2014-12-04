require './lib/controller_utils.rb'

class FeedsController < ApplicationController
  
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
    # seeker_result Feed, 'div.feed_list', all_feeds: permitted_to?(:approve, :feeds) # , clear_tags: true
  end

  # GET /feeds/1
  # GET /feeds/1.json
  def show
    @active_menu = :feeds
    begin
      update_and_decorate
      response_service.title = @feed.title
      smartrender unless do_stream FeedCache do |sp|
        sp.item_partial = "feed_entries/show_feed_entry"
        sp.results_partial = "stream_results_items"
      end
#    rescue Exception => e
#      render text: "Sorry, but there is no such feed. Whatever made you ask?"
    end
  end

  # GET /feeds/new
  # GET /feeds/new.json
  def new
    @feed = Feed.new
    response_service.title = "Subscribe to a Feed"
    smartrender mode: :modal
  end
  
  # Add a feed to the feeds of the current user
  def collect
    if current_user
      update_and_decorate
      if current_user.collected? @feed
        flash[:alert] = "You're already subscribed to '#{@feed.title}'."
        render :errors
      else
        current_user.collect @feed # Selects the feed whether previously subscribed or not
        current_user.save
        if current_user.errors.empty?
          flash[:notice] = "Now feeding you with '#{@feed.title}'."
        else
          post_resource_errors current_user
          render :errors
        end
      end
    else
      flash[:error] = "Sorry, but you can only subscribe to a feed when you're logged in."
      render :errors
    end
  end
  
  # Remove a feed from the current user's feeds
  def remove
    update_and_decorate
    if current_user && @feed
      current_user.uncollect @feed
      current_user.save
      flash[:popup] = "Unsubscribed"+(@feed.title.empty? ? "..." : (" from "+@feed.title))
      render :collect
    else
      flash[:error] ||= ": No current user"
      render :errors
    end
  end

  # GET /feeds/1/edit
  def tag
    update_and_decorate
    smartrender
  end

  # POST /feeds
  # POST /feeds.json
  def create
    update_and_decorate
    # URLs uniquely identify feeds, so we may have clashed with an existing one.
    # If so, simply adopt that one.
    # NB If so, we merrily ignore the other attributes being provided as parameters--if any
    if @feed.errors.any?
      @feed = (Feed.where url: @feed.url)[0] || @feed
    end
    if @feed.errors.any?
      post_resource_errors @feed
      render :new, status: :unprocessable_entity, mode: :modal
    else
      redirect_to collect_feed_path
    end
  end

  # PUT /feeds/1
  # PUT /feeds/1.json
  def update
    if update_and_decorate
      respond_to do |format|
        format.html {
          redirect_to feeds_url, :status => :see_other, notice: 'Feed '#{@feed.title}' was successfully updated.'
        }
        format.json {
          flash[:popup] = "#{@feed.title} updated"
          render :update
        }
      end
    else
      post_resource_errors @feed
      render :edit
    end
  end

  def refresh
    update_and_decorate
    if @feed.status == "ready"
      if Rails.env.development?
        n_entries = @feed.feed_entries.size
        @feed.refresh
        n_new = @feed.feed_entries.size - n_entries
        flash[:popup] = labelled_quantity(n_new, "New entry")+" found"
        render :refresh, locals: { :followup => (n_new > 0) }
      else
        @feed.enqueue_update
        flash[:popup] = "Feed update starting..."
        render :errors
      end
    else
      flash[:popup] = "Feed update is still in process"
      render :errors
    end
    post_resource_errors @feed
  end

  # DELETE /feeds/1
  # DELETE /feeds/1.json
  def destroy
    @feed = Feed.find params[:id]
    @feed.destroy

    respond_to do |format|
      format.html { redirect_to feeds_url }
      format.json { head :no_content }
    end
  end
end

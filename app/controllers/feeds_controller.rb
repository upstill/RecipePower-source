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
    if post_resource_errors @feed
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
          redirect_to feeds_url, :status => :see_other, notice: "Feed '#{@feed.title}' was successfully updated."
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
      # if Rails.env.development? # Immediate refresh
        n_entries = @feed.feed_entries.size
        @feed.refresh
        n_new = @feed.feed_entries.size - n_entries
        if post_resource_errors(@feed)
          render :errors
        else
          flash[:popup] = labelled_quantity(n_new, "New entry")+" found"
          render :refresh, locals: { :followup => (n_new > 0) }
        end
=begin
      else
        @feed.enqueue_update
        flash[:popup] = "Feed update starting..."
        render :errors
      end
=end
    else
      flash[:popup] = "Feed update is still in process"
      render :errors
    end
  end

  # DELETE /feeds/1
  # DELETE /feeds/1.json
  def destroy
    if update_and_decorate
      @feed.destroy
      render :errors if post_resource_errors( @feed )
    else
      flash[:alert] = "Can't locate Feed ##{params[:id] || '<unknown>'}"
      render :errors
    end
  end
end

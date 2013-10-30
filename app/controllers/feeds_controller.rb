require './lib/controller_utils.rb'

class FeedsController < ApplicationController
  
  def approve
    @feed = Feed.find(params[:id])
    @feed.approved = params[:approve] == 'Y'
    @feed.save
    if request.format == 'text/javascript'
      @user = current_user
      @notice = 'Feedthrough '+(@feed.approved ? "Approved" : "Blocked")
    else
      flash[:notice] = 'Feedthrough '+(@feed.approved ? "Approved" : "Blocked")
      redirect_to feeds_path
    end
  end
  
  # GET /feeds
  # GET /feeds.json
  def index
    collection_result Feed, clear_tags: true, all_feeds: permitted_to?(:approve, :feeds)
  end
  
  # Query takes either a query string or a specification of page number
  # We return a recipe list IFF the :cached parameter is not set
  def query
    collection_result Feed, all_feeds: permitted_to?(:approve, :feeds)
  end

  # GET /feeds/1
  # GET /feeds/1.json
  def show
    @feed = Feed.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @feed }
    end
  end

  # GET /feeds/new
  # GET /feeds/new.json
  def new
    @feed = Feed.new
    @Title = "Subscribe to a Feed"
    # @_area = params[:_area]
    # dialog_boilerplate 'new', 'modal'
    smartrender area: 'modal'
  end
  
  # Add a feed to the feeds of the current user
  def collect
    @feed = Feed.find params[:id]
    user = current_user_or_guest
    if @feed.user_ids.include?(user.id)
      @notice = "You're already subscribed to '#{@feed.title}'."
    else
      @feed.approved = true
      @feed.users << user 
      @feed.save
      @feed.perform
      @notice = "Now feeding you with '#{@feed.title}'."
    end
    @node = user.add_feed @feed # No harm if the user already has the feed
    @browser = user.browser
    respond_to do |format|
      format.js { 
        flash[:notice] = @notice 
        render text: "RP.get_page(\""+collection_path+"\");"
      }
      format.html { redirect_to collection_path, notice: @notice }
      format.json { 
        render(
          json: { 
            processorFcn: "RP.content_browser.insert_or_select",
            entity: with_format("html") { render_to_string partial: "collection/node", locals: { b: 2 } }, 
            notice: view_context.flash_one(:notice, @notice) 
          }, 
          status: :created, 
          location: @feed 
      )}
    end
  end
  
  # Remove a feed from the current user's feeds
  def remove
    begin
      feed = Feed.find(params[:id])
    rescue Exception => e
      flash[:error] = "Couldn't get feed "+params[:id].to_s
    end
    if current_user && feed
      current_user.delete_feed feed
      current_user.save
      flash[:notice] = "There you go! Unsubscribed"+(feed.title.empty? ? "..." : (" from "+feed.title))
    else
      flash[:error] ||= ": No current user"
    end
    redirect_to collection_path
  end

  # GET /feeds/1/edit
  def edit
    @feed = Feed.find(params[:id])
    # dialog_boilerplate "edit", "floating" 
    smartrender area: "floating" 
  end

  # POST /feeds
  # POST /feeds.json
  def create
    user = current_user_or_guest
    @feed = Feed.create params[:feed]
    # URLs uniquely identify feeds, so we may have clashed with an existing one.
    # If so, simply adopt that one.
    # NB If so, we merrily ignore the other attributes being provided as parameters--if any
    if @feed.errors.any?
      @feed = (Feed.where url: @feed.url)[0] || @feed
    end
    if @feed.errors.any?
      resource_errors_to_flash_now @feed # Move resource errors into the flash
      respond_to do |format|
        format.html { render action: "new", status: :unprocessable_entity }
        format.json { 
          # @_area = "floating"
          # dialog_boilerplate "new", "modal", status: :unprocessable_entity 
          smartrender action: "new", area: "modal", status: :unprocessable_entity 
        }
      end
    else
      redirect_to collect_feed_path(@feed)
    end
  end

  # PUT /feeds/1
  # PUT /feeds/1.json
  def update
    @feed = Feed.find(params[:id])
    @user = current_user
    if @feed.update_attributes(params[:feed])
      respond_to do |format|
        format.html { redirect_to feeds_url, :status => :see_other, notice: 'Feed was successfully updated.' }
        format.json { render json: { 
                        done: true, 
                        replacements: [ [ "#feed"+@feed.id.to_s, with_format("html") { render_to_string partial: "feeds/feed" } ] ],
                        popup: "Feed saved" } 
                    }
      end
    else
      respond_to do |format|
        format.html { render action: "edit" }
        format.json { render json: @feed.errors[:url], status: :unprocessable_entity }
      end
    end
  end

  # DELETE /feeds/1
  # DELETE /feeds/1.json
  def destroy
    @feed = Feed.find(params[:id])
    @feed.destroy

    respond_to do |format|
      format.html { redirect_to feeds_url }
      format.json { head :no_content }
    end
  end
end

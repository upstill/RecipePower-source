require './lib/controller_utils.rb'

class FeedsController < ApplicationController
  
  def approve
    @feed = Feed.find(params[:id])
    @feed.approved = params[:approve] == 'Y'
    @feed.save
    redirect_to feeds_path, :notice => 'Feedthrough '+(@feed.approved ? "Approved" : "Blocked")
  end
  
  # GET /feeds
  # GET /feeds.json
  def index
    @feeds = Feed.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @feeds }
    end
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
    @area = params[:area]
    dialog_boilerplate 'new', 'modal'
  end
  
  # Add a user to the friends of the current user
  def collect
  end
  
  # Remove a user from the friends of the current user
  def remove
    begin
      feed = Feed.find(params[:id])
    rescue Exception => e
      flash[:error] = "Couldn't get feed "+params[:id].to_s
    end
    if current_user && feed
      current_user.delete_feed feed
      current_user.save
      flash[:notice] = "There you go! Unsubscribed from "+feed.description
    else
      flash[:error] ||= ": No current user"
    end
    redirect_to collection_path
  end

  # GET /feeds/1/edit
  def edit
    @feed = Feed.find(params[:id])
  end

  # POST /feeds
  # POST /feeds.json
  def create
    @feed = Feed.where(url: params[:feed][:url]).first || Feed.new(params[:feed])
    @feed.approved = true
    @feed.users << current_user_or_guest unless @feed.user_ids.include?(current_user_or_guest_id)
    respond_to do |format|
      if @feed.update_attributes(params[:feed])
        user = current_user_or_guest
        @node = user.add_feed @feed
        flash[:notice] = "Now feeding you with '#{@feed.description}'"
        format.html { redirect_to collection_path }
        format.json { 
          rs = with_format("html") do render_to_string :partial => "collection/node" end
          json_data = { 
            processorFcn: "RP.content_browser.insert_or_select",
            entity: rs, 
            notice: view_context.notification_out(notice, :notice) 
          }
          render json: json_data, status: :created, location: @feed 
        }
      else
        format.html { render action: "new" }
        format.json { render json: view_context.errors_helper(@feed, :url), status: :unprocessable_entity }
      end
    end
  end

  # PUT /feeds/1
  # PUT /feeds/1.json
  def update
    @feed = Feed.find(params[:id])

    respond_to do |format|
      if @feed.update_attributes(params[:feed])
        format.html { redirect_to @feed, notice: 'Feed was successfully updated.' }
        format.json { head :no_content }
      else
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

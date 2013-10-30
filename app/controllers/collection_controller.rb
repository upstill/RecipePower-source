class CollectionController < ApplicationController
  layout :rs_layout # Let response_service pick the layout
  before_filter :setup_collection, except: [ :index, :query ]
  after_filter :save_browser
  
  def save_browser
    @user.save
  end
  
  def user_only
    if user_signed_in?
      render action: 'index'
    else
		flash.keep
      redirect_to home_path
    end
  end
  
  def index
    collection_result "Content", clear_tags: true, :selector => 'div.collection'
  end

  def query
    collection_result "Content", :selector => 'div.collection'
  end
  
  def show
  end

  def new
  end

  def edit
  end

  def create
  end
  
  # Update the collection to reflect any changes
  def update
    @seeker.refresh # Set the refresh process going
    respond_to do |format|
      format.html { 
        render :text => "Refreshing..."
      }
    end
  end 

  # Render the results for the current state of the query and selected collection
  def relist
    otime = params[:mod_time] 
    ntime = @seeker.updated_at.to_s
    flash.now[:guide] = @seeker.guide
    if otime == ntime # awaiting update
      render :nothing => true, :status => :no_content
    else
      flash.now[:success] = "This feed is now up to date."
      render :index, :layout=>false, :locals => { :feed => @feed }
    end
  end
end

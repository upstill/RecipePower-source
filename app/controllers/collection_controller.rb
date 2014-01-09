class CollectionController < ApplicationController
  layout :rs_layout # Let response_service pick the layout
  before_filter :setup_collection, except: [ :index ]
  after_filter :save_browser
  
  def save_browser
    @user.save if @user
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
    @Title = "Collections"
    seeker_result "Content", 'div.collection' # , clear_tags: true
  end

=begin
  def query
    seeker_result "Content", 'div.collection'
  end
=end
  
  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  def update
  end

  # Update the collection to reflect any changes
  def refresh
    @seeker.refresh # Set the refresh process going
    seeker_result "Content", 'div.collection'
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
      @Title = "Collections"
      seeker_result "Content", 'div.collection'
      # render :index, :layout=>false, :locals => { :feed => @feed }
    end
  end
end

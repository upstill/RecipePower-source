class CollectionController < ApplicationController
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
    if otime == ntime # awaiting update
      render :nothing => true, :status => :no_content
    else
      flash.now[:success] = "This feed is now up to date."
      render :index, :layout=>false, :locals => { :feed => @feed }
    end
  end

  # Update takes either a query string or a specification of a collection now selected
  # We return a recipe list IFF the :cached parameter is not set
  def query
    if id = params[:selected]
      @browser.select_by_id(params[:selected])
    end
    if tagstxt = params[:tagstxt]
      @seeker.tagstxt = tagstxt
    end
    if page = params[:cur_page]
      @seeker.cur_page = page.to_i
    end
    render :index, :layout=>false
  end
end

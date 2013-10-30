class CollectionController < ApplicationController
  layout :rs_layout # Let response_service pick the layout
  before_filter :setup_collection
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
    list
  end

  # Update takes either a query string or a specification of a collection now selected
  # We return a recipe list IFF the :cached parameter is not set
  def query
    list
  end
  
  def list
    flash.now[:guide] = @seeker.guide
    respond_to do |format|
      format.html { # Render the whole page
        render :index
      }
      format.json { 
        # In a json response we just re-render the collection list for replacement
        # If we need to replace the page, we send back a link to do it with
        if params[:redirect]
          render json: { 
            # page: with_format("html") { render_to_string :index },
            redirect: collection_url( params.slice 'context' )
          }
        else
          list = with_format("html") { render_to_string :index, :layout => false }
          replacement = ["div.collection", list]
          render json: { replacements: [ replacement ] }
        end
      }
    end
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

class CollectionController < ApplicationController
  before_filter :setup_collection
  after_filter :save_browser
  
  # All controllers displaying the collection need to have it setup 
  def setup_collection
    if popup = params[:popup]
      session[:flash_popup] = popup
      redirect_to collection_path
    else
      @user = current_user_or_guest
      @browser = @user.browser
      @seeker = ContentSeeker.new @browser, session[:seeker], params # Default; other controllers may set up different seekers
      @seeker.tagstxt = "" if (params[:action] == "index")
      session[:seeker] = @seeker.store
    end
  end
  
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
    flash.now[:guide] = @seeker.guide
    respond_to do |format|
      format.html { }
      format.json { 
        # In a json response we just re-render the collection list for replacement
        # If we need to replace the page, we send back a link to do it with
        if params[:href]
          render json: { 
            # page: with_format("html") { render_to_string :index },
            href: collection_url( params.slice 'context' )
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

  # Update takes either a query string or a specification of a collection now selected
  # We return a recipe list IFF the :cached parameter is not set
  def query
    if id = params[:selected]
      @browser.select_by_id(params[:selected])
      @seeker.cur_page = 1
    end
    if tagstxt = params[:tagstxt]
      @seeker.tagstxt = tagstxt
      @seeker.cur_page = 1
    end
    if page = params[:cur_page]
      @seeker.cur_page = page.to_i
    end
    flash.now[:guide] = @seeker.guide
    render :index, :layout=>false
  end
end

class CollectionController < ApplicationController
  layout "collection"
  before_filter :fetch_browser
  after_filter :save_browser
  
  def fetch_browser
    @user_id = current_user_or_guest_id 
    @user = User.find(@user_id)
    @collection = @user.browser
  end    
  
  def save_browser
    @user.save
  end
  
  def index
	  # logger.debug render_to_string 
  end
  
  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  # Render the results for the current state of the query and selected collection
  def relist
    render '_relist.html.erb', :layout=>false
  end

  # Accept a revised query and return a new list
  def query
    render '_relist', :layout=>false
  end

  # Update takes either a query string or a specification of a collection now selected
  # We return a recipe list IFF the :cached parameter is not set
  def update
    if tagstxt = params[:tagstxt]
      @collection.tagstxt = tagstxt
    end
    if id = params[:selected]
      @collection.select_by_id(params[:selected].delete("RcpBrowserElement").to_i)
    end
    if page = params[:cur_page]
      @collection.cur_page = page.to_i
    end
    render '_relist', :layout=>false
  end
end

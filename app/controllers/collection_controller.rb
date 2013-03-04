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

  # Render the results for the current state of the query and selected collection
  def relist
    render '_relist', :layout=>false
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
    render '_relist', :layout=>false
  end
end

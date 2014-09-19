class CollectionController < ApplicationController
=begin
  layout :rs_layout # Let response_service pick the layout
  # before_filter :setup_collection # , except: [ :index ]
  # after_filter :save_browser
  
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
    response_service.title = "Collections"
    @rp_old = false
    seeker_result "Content", 'div.collection' # , clear_tags: true
  end

  def show
  end

  # GET /collection/new
  # GET /collection/new.xml
  def new
    response_service.title = "Tags"
    @tag = Tag.new
    smartrender
  end

  def edit
  end

  # POST /collection
  # POST /collection.xml
  def create
      response_service.title = "New Collection"
      respond_to do |format|
        if @tag = Tag.assert(params[:tag][:name], userid: current_user.id)
          current_user.add_collection @tag
          # Create the collection, private to user
          # Make the collection current in the browser
          notice = "You now have a '#{@tag.name}' Collection, and you can add any recipe to it."
          format.html { redirect_to controller: "collection", action: "index", notice: notice }
          format.json { render :json => { done: true, notice: notice, redirect: collection_path } }
          format.xml  { render :xml => @tag, :status => :created, :location => @tag }
        else
          @tag = Tag.new(name: params[:tag][:name])
          format.html
          format.json
          format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
        end
      end
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
    # flash.now[:guide] = @seeker.guide
    if otime == ntime # awaiting update
      render :nothing => true, :status => :no_content
    else
      flash.now[:success] = "This feed is now up to date."
      seeker_result "Content", 'div.collection'
      # render :index, :layout=>false, :locals => { :feed => @feed }
    end
  end
=end
end

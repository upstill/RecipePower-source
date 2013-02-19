class UsersController < ApplicationController
  layout "collection"
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  before_filter :login_required, :except => [:new, :create, :identify]
  before_filter :authenticate_user!, :except => [:show, :index, :identify]
  # before_filter :declare_focus
  
  def declare_focus
    @focus_selector = "#user_login"
  end
  
  # GET /users
  # GET /users.xml
  def index
      # 'index' page may be calling itself with filter parameters in the name and tagtype
      @Title = "Users"
      @user = current_user_or_guest
      @isChannel = params[:channel] && (params[:channel]=="true")
      @users = @isChannel ? 
        User.where("channel_referent_id > 0") : 
        User.where("channel_referent_id = 0 AND id not in (?)", @user.followee_ids + [@user.id, 4, 5])
      @seeker = FriendSeeker.new @users, session[:seeker] # Default; other controllers may set up different seekers
      # @filtertag.tagtype = params[:tag][:tagtype].to_i unless params[:tag][:tagtype].blank?
      @userlist = User.scoped.order("id").page(params[:page]).per_page(50)
    respond_to do |format|
      format.json { render :json => @taglist.map { |tag| { :title=>tag.name+tag.id.to_s, :isLazy=>false, :key=>tag.id, :isFolder=>false } } }
      format.html # index.html.erb
      format.xml  { render :xml => @taglist }
    end
  end
  
  # Add a user or channel to the friends of the current user
  def collect
    @friend = User.find params[:id]
    user = current_user_or_guest
    debugger
    if user.followee_ids.include?(@friend.id)
      flash[:notice] = "You're already following '#{@friend.handle}'."
    else
      @node = user.add_followee @friend
      flash[:notice] = "You're now connected with '#{@friend.handle}'."
    end
    respond_to do |format|
      format.html { redirect_to collection_path }
      format.json { 
        render( 
          json: { 
            processorFcn: "RP.content_browser.insert_or_select",
            entity: with_format("html") { render_to_string :partial => "collection/node" }, 
            notice: view_context.notification_out(notice, :notice) 
          }, 
          status: :created, 
          location: @friend 
        )
      }
    end
  end
  
  # Query takes either a query string or a specification of page number
  # We return a recipe list IFF the :cached parameter is not set
  def query
    @isChannel = params[:channel] && (params[:channel]=="true")
    @users = @isChannel ? User.where("channel_referent_id > 0") : User.where(:channel_referent_id => 0)
    @seeker = FriendSeeker.new @users, session[:seeker] # Default; other controllers may set up different seekers
    @user = current_user_or_guest
    if tagstxt = params[:tagstxt]
      @seeker.tagstxt = tagstxt
    end
    if page = params[:cur_page]
      @seeker.cur_page = page.to_i
    end
    session[:seeker] = @seeker.store
    render '_relist', :layout=>false
  end
  
  def new
    @user = User.new
    @Title = "Create RecipePower Account"
    if(!session[:user_id])
       redirect_to new_visitor_url, :notice => "Sorry, but RecipePower is not open for business as yet. Stay tuned, or sign up for our mailing list"
    end
  end
  
  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    @user = User.find(params[:id])
    @user.destroy
    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end
  
  def show
    @user = User.find params[:id]
  end
  
  def not_found
    redirect_to root_path, :notice => "User not found"
  end

  # With devise handling user creation, the only way we get here is from the 'identify' page.
  # If the user has provided an email address (whether in the 'new user' or 'existing user' section),
  # we try to match it to a user record. If no matchable email was provided, we create a new user.
  def create
  end
  
  # Remove a user from the friends of the current user
  def remove
    begin
      followee = User.find(params[:id])
    rescue Exception => e
      flash[:error] = "Couldn't find followee "+params[:id].to_s
    end
    if current_user && followee
      current_user.delete_followee followee
      current_user.save
      flash[:notice] = "There you go! No longer following "+followee.handle
    else
      flash[:error] ||= ": No current user"
    end
    redirect_to collection_path
  end

  def edit
    if @user = ((params[:id] && User.find(params[:id])) || current_user)
        @authentications = @user.authentications
    end
    @Title = "Edit Profile"
  end
  
  def profile
    if @user = current_user
      @authentications = @user.authentications
    end
    @Title = "Edit Profile"
    render :action => 'edit'
  end
  
  # Ask user for an email address for login purposes
  def identify
    @user = User.new
    # if omniauth = session[:omniauth]
      # @user.apply_omniauth(omniauth)
    # end
  end

  def update
    @user = User.find params[:id]
    if @user.update_attributes(params[:user])
      @user.refresh_browser # Assuming, perhaps incorrectly, that the browser contents have changed
      @Title = "Cookmarks from Update"
      redirect_to recipes_path, :notice => "Your profile has been updated."
    else
      @Title = "Edit Profile"
      render :action => 'edit'
    end
  end

end

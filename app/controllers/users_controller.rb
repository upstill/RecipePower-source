require './lib/controller_utils.rb'

class UsersController < ApplicationController
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  before_filter :login_required, :except => [:new, :create, :identify]
  before_filter :authenticate_user!, :except => [:show, :index, :identify]
  before_filter :setup_seeker, :only => [:index, :query ]
  # before_filter :declare_focus
  
  def declare_focus
    @focus_selector = "#user_login"
  end
  
  def setup_seeker
    @isChannel = params[:channel] && (params[:channel]=="true")
    @users = @isChannel ? 
      User.where("channel_referent_id > 0 AND id not in (?)", @user.followee_ids + [@user.id, 4, 5]) : 
      User.where("channel_referent_id = 0 AND id not in (?) AND private != true", @user.followee_ids + [@user.id, 4, 5])
    @seeker = FriendSeeker.new @users, session[:seeker] # Default; other controllers may set up different seekers
  end
  
  # GET /users
  # GET /users.xml
  def index
    # 'index' page may be calling itself with filter parameters in the name and tagtype
    @Title = "Users"
    @user = current_user_or_guest
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
    if user.followee_ids.include?(@friend.id)
      notice = "You're already following '#{@friend.handle}'."
    else
      @node = user.add_followee @friend
      notice = "You're now connected with '#{@friend.handle}'."
    end
    respond_to do |format|
      format.html { redirect_to collection_path, :notice => notice }
      format.json { 
        render( 
          json: { 
            processorFcn: "RP.content_browser.insert_or_select",
            entity: with_format("html") { render_to_string :partial => "collection/node" }, 
            notice: view_context.flash_one(:notice, notice) 
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
    @seeker = FriendSeeker.new @users, session[:seeker] # Default; other controllers may set up different seekers
    @user = current_user_or_guest
    if tagstxt = params[:tagstxt]
      @seeker.tagstxt = tagstxt
    end
    if page = params[:cur_page]
      @seeker.cur_page = page.to_i
    end
    session[:seeker] = @seeker.store
    render 'index', :layout=>false
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
    @section = params[:section] || "profile"
    @Title = "Edit Profile"
    dialog_boilerplate "edit", "floating" 
  end
  
  # Ask user for an email address for login purposes
  def identify
    @user = User.new
    if omniauth = session[:omniauth]
      @provider = omniauth.provider.capitalize
      @user.apply_omniauth(omniauth)
    end
  end
  
  def profile
    if @user = current_user
      @authentications = @user.authentications
    end
    @section = params[:section] || "profile"
    @Title = "My "+@section.capitalize
    # render :action => 'edit'
    dialog_boilerplate "edit", "floating" 
  end

  def update
    @user = User.find params[:id]
    if @user.update_attributes(params[:user])
      @user.refresh_browser # Assuming, perhaps incorrectly, that the browser contents have changed
      @Title = "Cookmarks from Update"
      flash[:message] = (@user == current_user ? "Your profile" : @user.handle+"'s profile")+" has been updated."
      respond_to do |format|
        format.html { redirect_to collection_path }
        format.json  { 
          listitem = with_format("html") { render_to_string( partial: "user" ) }
          render json: {
            replacements: [ ["#listrow_"+@user.id.to_s, listitem], view_context.flash_notifications_replacement ]
          }
        }
      end
    else
      @section = params[:user][:email] ? "profile" : "account"
      @Title = "Edit #{@section}"
      dialog_boilerplate "edit", "floating" 
    end
  end

end

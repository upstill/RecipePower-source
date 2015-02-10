require './lib/controller_utils.rb'
require 'suggestion.rb'

class UsersController < CollectibleController
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  before_filter :login_required, :except => [:new, :create, :identify]
  before_filter :authenticate_user!, :except => [:new, :show, :index, :identify]

  # Take a tokenInput query string and match the input against the given user's set of friends/channels
  def match_friends
    me = User.find params[:id]
    respond_to do |format|
      format.json { 
        friends = me.match_friends(params[:q], params[:channel]).collect { |friend|
          name = friend.handle
          name << " (#{friend.email})" unless params[:channel]
          { id: friend.id.to_s, name: name }
        }
        if friends.empty? 
          if params[:q].match(Devise::email_regexp)
            # A "valid" address goes back paired with itself
            friends = [ { id: params[:q], name: params[:q] } ]
          end
        end
        render :json => friends
      }
    end
  end
  
  # GET /users
  # GET /users.xml
  def index
    # 'index' page may be calling itself with filter parameters in the name and tagtype
    @select = params[:select]
    response_service.title = (@select=="followees") ? "Friends" : "People"
    smartrender unless do_stream UsersCache
  end

  # Add a user or channel to the friends of the current user
  def follow
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      if current_user.follows? @user
        current_user_or_guest.followees.delete @user
        msg = "You've just been unplugged from'#{@user.handle}'."
      else
        current_user_or_guest.followees << @user
        msg = "You're now connected with '#{@user.handle}'."
      end
      current_user.save
      @user.save
      if post_resource_errors(current_user)
        render :errors
      else
        flash[:popup] = msg
        render :follow
      end
    else
      flash[:alert] = "Sorry, you need to be logged in to follow someone."
      render :errors
    end
  end

  def new
    @user = User.new
    response_service.title = "Create RecipePower Account"
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
    @active_menu = :home
    update_and_decorate
    smartrender unless do_stream UserListsCache
  end

  # Show the user's recently-viewed recipes
  def recent
    @user = User.find params[:id]
    @active_menu = :collections
    @empty_msg = "As you check out things in RecipePower, they will be remembered here."
    response_service.title = "Recently Viewed"
    smartrender unless do_stream UserRecentCache
  end

  # Show the user's entire collection
  def collection
    @user = User.find params[:id]
	  if (@user.id == current_user_or_guest_id)
      response_service.title = "My Whole Collection"
      @empty_msg = "Nothing here yet...but that's what the #{view_context.link_to_submit 'Cookmark Button', '/popup/starting_step2'} is for!".html_safe
      @active_menu = :collections
    else
      response_service.title = "#{@user.handle}'s Collection"
      @empty_msg = "They haven't collected anything?!? Why not Share something with them?"
      @active_menu = :friends
    end
    smartrender unless do_stream UserCollectionCache
  end

  # Show the user's recently-viewed recipes
  def biglist
    @user = User.find params[:id]
    @active_menu = :collections
    response_service.title = "The Big List"
    smartrender unless do_stream UserBiglistCache
  end

  def not_found
    redirect_to root_path, :notice => "User not found", method: "get"
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
      current_user.followees.delete followee
      current_user.save
      flash[:notice] = "There you go! No longer following "+followee.handle
    else
      flash[:error] ||= ": No current user"
    end
    redirect_to root_path
  end

  def edit
    update_and_decorate
    @authentications = @user.authentications if @decorator.id
    @section = params[:section] || "profile"
    response_service.title = "Edit Profile"
    smartrender
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
    params[:id] = current_user.id if current_user
    update_and_decorate
    @authentications = @user.authentications if @decorator.id
    @section = params[:section] || "profile"
    response_service.title = "My "+@section.capitalize
    smartrender action: "edit"
  end

  def getpic
    update_and_decorate
  end

  def update
    if update_and_decorate
      response_service.title = "Cookmarks from Update"
      flash[:message] = (@user == current_user ? "Your profile" : @user.handle+"'s profile")+" has been updated."
    else
      @section = params[:user][:email] ? "profile" : "account"
      response_service.title = "Edit #{@section}"
      smartrender action: "edit", mode: "modal"
    end
  end

end

require './lib/controller_utils.rb'

class UsersController < ApplicationController
  
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  before_filter :login_required, :except => [:new, :create, :identify]
  before_filter :authenticate_user!, :except => [:new, :show, :index, :identify]
  
  # Take a tokenInput query string and match the input against the given user's set of friends/channels
  def match_friends
    me = User.find params[:id]
    respond_to do |format|
      format.json { 
        friends = me.match_friends(params[:q]).collect { |friend| 
          { id: friend.id.to_s, name: (friend.handle+" (#{friend.email})") }
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
    @Title = "Users"
    seeker_result User, 'div.user_list' # , clear_tags: true
  end
  
=begin
  # Query takes either a query string or a specification of page number
  # We return a recipe list IFF the :cached parameter is not set
  def query
    seeker_result User, 'div.user_list'
  end
=end
  
  # Add a user or channel to the friends of the current user
  def collect
    @friend = User.find params[:id]
    user = current_user_or_guest
    if user.followee_ids.include?(@friend.id)
      notice = "You're already following '#{@friend.handle}'."
    else
      user.add_followee @friend
      notice = "You're now connected with '#{@friend.handle}'."
    end
    respond_to do |format|
      format.html { redirect_to collection_path, :notice => notice }
      format.json {
        @browser = user.browser
        @node = @browser.selected
        render(
          json: { 
            processorFcn: "RP.content_browser.insert_or_select",
            entity: with_format("html") { render_to_string partial: "collection/node" }, 
            notice: view_context.flash_one(:notice, notice) 
          }, 
          status: :created, 
          location: @friend 
        )
      }
    end
  end
  
  def new
    @user = User.new
    @Title = "Create RecipePower Account"
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
    smartrender :how => :modal
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
    # dialog_boilerplate "edit", "floating" 
    smartrender area: "floating" 
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
    # dialog_boilerplate "edit", "floating" 
    smartrender action: "edit", area: "floating" 
  end

  def update
=begin
    account_update_params = devise_parameter_sanitizer.sanitize(:account_update)
    # required for settings form to submit when password is left blank
    if account_update_params[:password].blank?
      account_update_params.delete("password")
      account_update_params.delete("password_confirmation")
    end
=end

    @user = User.find params[:id]
    if @user.update_attributes(params[:user])
      @user.refresh_browser # Assuming, perhaps incorrectly, that the browser contents have changed
      @Title = "Cookmarks from Update"
      flash[:message] = (@user == current_user ? "Your profile" : @user.handle+"'s profile")+" has been updated."
      respond_to do |format|
        format.html { redirect_to collection_path }
        format.json  { 
          listitem = with_format("html") { render_to_string( partial: "show_table_row") }
          render json: {
            done: true,
            replacements: [ ["#listrow_"+@user.id.to_s, listitem], view_context.flash_notifications_replacement ]
          }
        }
      end
    else
      @section = params[:user][:email] ? "profile" : "account"
      @Title = "Edit #{@section}"
      # dialog_boilerplate "edit", "floating" 
      smartrender action: "edit", area: "floating" 
    end
  end

end

class UsersController < ApplicationController
  before_filter :login_required, :except => [:new, :create, :identify]
  before_filter :authenticate_user!, :except => [:show, :index]
  
  def new
    @user = User.new
    @Title = "Create RecipePower Account"
    if(!session[:user_id])
       redirect_to new_visitor_url, :notice => "Sorry, but RecipePower is not open for business as yet. Stay tuned, or sign up for our mailing list"
    end
  end

  # With devise handling user creation, the only way we get here is from the 'identify' page.
  # If the user has provided an email address (whether in the 'new user' or 'existing user' section),
  # we try to match it to a user record. If no matchable email was provided, we create a new user.
  def create
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
      @Title = "Cookmarks from Update"
      redirect_to recipes_path, :notice => "Your profile has been updated."
    else
      @Title = "Edit Profile"
      render :action => 'edit'
    end
  end
end

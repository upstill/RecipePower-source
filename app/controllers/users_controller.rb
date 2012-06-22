class UsersController < ApplicationController
  before_filter :login_required, :except => [:new, :create]

  def new
    @user = User.new
    @Title = "Create Account"
    if(!session[:user_id])
       redirect_to new_visitor_url, :notice => "Sorry, but RecipePower is not open for business as yet. Stay tuned, or sign up for our mailing list"
    end
  end

  def create
    @user = User.new(params[:user])
    @Title = "New User"
    if @user.save
      session[:user_id] = @user.id
      redirect_to recipes_path, :notice => "Thank you for signing up! You are now logged in."
    else
      render :action => 'new'
    end
  end

  def edit
    debugger
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

class UsersController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  before_filter :login_required, :except => [:new, :create, :identify]
  before_filter :authenticate_user!, :except => [:show, :index, :identify]

  # GET /tags
  # GET /tags.xml
  def index
      # 'index' page may be calling itself with filter parameters in the name and tagtype
      @Title = "Users"
      # @filtertag.tagtype = params[:tag][:tagtype].to_i unless params[:tag][:tagtype].blank?
      @userlist = User.scoped.order("id").page(params[:page]).per_page(50)
    respond_to do |format|
      format.json { render :json => @taglist.map { |tag| { :title=>tag.name+tag.id.to_s, :isLazy=>false, :key=>tag.id, :isFolder=>false } } }
      format.html # index.html.erb
      format.xml  { render :xml => @taglist }
    end
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

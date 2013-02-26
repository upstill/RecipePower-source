class SessionsController < ApplicationController
  before_filter { @focus_selector = "#user_login" }

  def new
    @Title = "Login"
  end

  def create
    @Title = "Login"
    user = User.authenticate(params[:login], params[:password])
    if user
      session[:user_id] = user.id
      redirect_back :notice =>"Welcome back! (Logged in successfully.)"
    else
      flash.now[:alert] = "Invalid login or password."
      render :action => 'new'
    end
  end

  def destroy
    @Title = "Logout"
    session[:user_id] = nil
    redirect_to login_path, :notice => "Farewell, till we meet again! (You have been logged out.)"
  end
end

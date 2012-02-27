class SessionsController < ApplicationController

  def new
    @Title = "RecipePower Login"
  end

  def create
    @Title = "RecipePower Login"
    user = User.authenticate(params[:login], params[:password])
    if user
      session[:user_id] = user.id
      redirect_back rcpqueries_path, :notice =>"Welcome back! (Logged in successfully.)"
      # redirect_to_target_or_default recipes_path, :notice => "Welcome back! (Logged in successfully.)"
    else
      flash.now[:alert] = "Invalid login or password."
      render :action => 'new'
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, :notice => "Farewell, till we meet again! (You have been logged out.)"
  end
end

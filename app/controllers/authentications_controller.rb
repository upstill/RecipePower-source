class AuthenticationsController < ApplicationController
  def index
    @authentications = Authentication.all
  end

  def create
    # render :text => request.env['omniauth.auth'].to_yaml
    response = request.env['omniauth.auth']
    if @authentication = Authentication.find_or_create_by_provider_and_uid(response.slice('provider', 'uid'))
      current_user.authentications << @authentication if logged_in? # Link to existing user
      redirect_to authentications_url, :notice => "Yay! Successful Authentication via "+params[:provider]
    else
      render :action => 'new'
    end
  end

  def destroy
    @authentication = Authentication.find(params[:id])
    @authentication.destroy
    redirect_to authentications_url, :notice => "Successfully destroyed authentication."
  end
end

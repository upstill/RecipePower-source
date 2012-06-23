class AuthenticationsController < ApplicationController
  def index
    @authentications = current_user.authentications if current_user
    @auth_delete = true
  end

  def create
    # render :text => request.env['omniauth.auth'].to_yaml
    omniauth = request.env['omniauth.auth']
    # render text: omniauth.to_yaml
    authparams = omniauth.slice('provider', 'uid')
    if @authentication = Authentication.find_by_provider_and_uid(omniauth['provider'], omniauth['uid'])
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}."
      sign_in_and_redirect(:user, @authentication.user)
    elsif current_user
      current_user.apply_omniauth(omniauth)
      @authentication = current_user.authentications.create!(authparams) # Link to existing user
      redirect_to authentications_url, :notice => "Yay! Successful authentication via #{@authentication.provider_name}."
    elsif (info = omniauth['info']) && (email = info['email']) && (user = User.find_by_email(email))
      user.apply_omniauth(omniauth)
      @authentication = user.authentications.create!(authparams) # Link to existing user
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}."
      sign_in_and_redirect(:user, user)
    else
      # This is a new authentication (not previously linked to a user) and there is 
      # no current user to link it to. So we need to sign up the user to link it to
      user = User.new
      user.apply_omniauth(omniauth)
      @authentication = user.authentications.build(authparams)
      if user.save
        flash[:notice] = "Signed in successfully via #{@authentication.provider_name}."
        sign_in_and_redirect(:user, user)
      else
        session[:omniauth] = omniauth.except('extra')
        flash[:notice] = "To cement your identity into RecipePower, we need to confirm a username and email JUST THIS ONCE."
        redirect_to new_user_registration_url
      end
    end
  end

  def destroy
    @authentication = Authentication.find(params[:id])
    provider = @authentication.provider_name
    @authentication.destroy
    redirect_to authentications_url, :notice => "Successfully destroyed authentication. No more #{provider} authentication for you!"
  end
end

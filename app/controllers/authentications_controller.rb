require './lib/controller_utils.rb'
  
class AuthenticationsController < ApplicationController
    def index
      @authentications = current_user.authentications if current_user
      @auth_delete = true
      @auth_context = :manage
      flash[:notice] = params[:notice]
      @area = params[:area]
      @layout = params[:layout]
      dialog_boilerplate "index"
    end

  # Get a new authentication (==login)
  def new
      @authentications = current_user.authentications if current_user
      @auth_delete = true
      @auth_context = :manage
      flash[:notice] = params[:notice]
      @area = params[:area]
      dialog_boilerplate "new"
  end

  def failure
      redirect_to authentications_url, :notice => "Sorry, authentication failed."
  end
  
  def handle_unverified_request
      true
  end

  # Callback after omniauth authentication
  def create
    # render :text => request.env['omniauth.auth'].to_yaml
    omniauth = request.env['omniauth.auth']
    # render text: omniauth.to_yaml
    authparams = omniauth.slice('provider', 'uid')
    if @authentication = Authentication.find_by_provider_and_uid(omniauth['provider'], omniauth['uid'])
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}. Welcome back, #{@authentication.user.handle}!"
      # sign_in_and_redirect(:user, @authentication.user)
      result = sign_in_and_redirect @authentication.user # , :bypass => true
    elsif current_user
      current_user.apply_omniauth(omniauth)
      @authentication = current_user.authentications.create!(authparams) # Link to existing user
      redirect_to collection_url, :notice => "Yay! You'll now be able to login via #{@authentication.provider_name}."
    # This is a new authentication (not previously linked to a user) and there is 
    # no current user to link it to. It's possible that the authentication will come with
    # an email address which we can use to log the user in.
    elsif (info = omniauth['info']) && (email = info['email']) && (user = User.find_by_email(email))
      user.apply_omniauth(omniauth)
      @authentication = user.authentications.create!(authparams) # Link to existing user
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}. Nice to see you again, #{user.handle}!"
      sign_in_and_redirect(:user, user)
    elsif user = (session[:invitation_token] && User.where(:invitation_token => session[:invitation_token]).first)
        # If we have an invitation out for this user we go ahead and log them in
        user.username = session[:invitation_username]
        user.apply_omniauth(omniauth)
        @authentication = user.authentications.build(authparams)
        if user.save
          flash[:notice] = "Signed in via #{@authentication.provider_name}."
          if user.sign_in_count > 1
              flash[:notice] += " Welcome back, #{user.handle}!"
          end
          if user.invited?
              user.accept_invitation!
          end
          sign_in_and_redirect(:user, user)
        end
      end  
      # We haven't managed to get the user signed in by other means, but we still have an authorization
      if !current_user
        # The email didn't come in the authorization, so we now need to 
        # discriminate between an existing user(and have them log in) 
        # and a new user (and have them sign up). Time to throw the problem
        # over to the user controller, providing it with the authorization.
        session[:omniauth] = omniauth.except('extra')
        # flash[:notice] = "Hmm, that's a new one. Would you enter your email address below so we can sort out who you are?"
        flash[:notice] = nil
        redirect_to users_identify_url
      end
=begin
      @authentication = user.authentications.build(authparams)
      if user.save
        flash[:notice] = "Signed in via #{@authentication.provider_name}. Welcome back, #{user.handle}!"
        sign_in_and_redirect(:user, user)
      else
        # The email didn't come in the authorization, so we now need to 
        # discriminate between an existing user(and have them log in) 
        # and a new user (and have them sign up). Time to throw the problem
        # over to the user controller, providing it with the authorization.
        session[:omniauth] = omniauth.except('extra')
        # flash[:notice] = "Hmm, that's a new one. Would you enter your email address below so we can sort out who you are?"
        redirect_to users_identify_url
      end
=end
      session[:invitation_token] = nil
      session[:invitation_username] = nil
  end

  def destroy
    @authentication = Authentication.find(params[:id])
    provider = @authentication.provider_name
    @authentication.destroy
    redirect_to authentications_url, :status => 303, :notice => "All done. No more #{provider} authentication for you!"
  end
end

require './lib/controller_utils.rb'
require 'uri'

class AuthenticationsController < ApplicationController
  after_filter :allow_iframe, only: :new

  def index
    @authentications = current_user.authentications if current_user
    @auth_delete = true
    @auth_context = :manage
    smartrender
  end

  # Get a new authentication (==login)
  def new
    @authentications = current_user.authentications if current_user
    if current_user
      # flash[:notice] = "All signed in. Welcome back, #{current_user.handle}!"
      # redirect_to collection_path(redirect: true)
      redirect_to after_sign_in_path_for(current_user), notice: "All signed in. Welcome back, #{current_user.handle}!"
    end
    @auth_delete = true
    smartrender
  end

  # Get a new authentication (==login) for a specific user
  def verify
    @authentications = current_user.authentications if current_user
    if current_user
      # flash[:notice] = "All signed in. Welcome back, #{current_user.handle}!"
      # redirect_to collection_path(redirect: true)
      redirect_to after_sign_in_path_for(current_user), notice: "All signed in. Welcome back, #{current_user.handle}!"
    end
    @auth_delete = true
    @auth_context = :manage
    smartrender
  end

  def failure
    render 'callback', :layout => false
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
    # Our query parameters appear in env['omniauth.params']
    if origin_url = env['omniauth.origin']  # Remove any enclosing quotes
      origin_url.sub! /^"?([^"]*)"?/, '\\1'
    end
    # Originator is where we came from, so we can go back there if login fails
    if originator = env['omniauth.params']['originator']  # Remove any enclosing quotes
      originator.sub! /^"?([^"]*)"?/, '\\1'
    end
    # Check for existing authorization
    @authentication = Authentication.find_by_provider_and_uid(omniauth['provider'], omniauth['uid'])
    (info = omniauth['info']) && (email = info['email']) && (user = User.find_by_email(email))
    intention = env['omniauth.params']['intention'] # If intention is 'signup', don't accept existing authentications
    if intention == "signup"
      if @authentication || user # This authentication method already in use
        flash[:notice] = "That #{@authentication.provider_name} login is already in use on RecipePower.<br>Perhaps you just need to sign in?"
        response_service.amend originator
        url_to = originator
      else  # No user and no authentication: perfect
        # Just create the account, getting what we can get out of the authorization info
        (user = User.new).apply_omniauth(omniauth)
        response_service.amend originator
        if user.save
          @authentication = user.authentications.create!(authparams) # Link authorization to user
          sign_in user, :event => :authentication
          RpMailer.welcome_email(user).deliver
          flash[:notice] =
              %Q{Welcome to RecipePower, #{user.polite_name}! Introductory email is on its way. }
          url_to = after_sign_in_path_for(user)
        else
          # If user can't be saved, go back to edit params
          url_to = response_service.decorate_path(new_user_registration_url)
        end
      end
      # Intention is not signing up
    elsif current_user
      if @authentication # Authentication already in use
        if @authentication.user == current_user
          flash[:notice] = "You're already connected through #{@authentication.provider_name}!"
        else
          flash[:notice] = "Sorry, your current #{@authentication.provider_name} login is tied to another RecipePower user."
        end
      else
        # Add the authentication method to the current user. We return to the authentications dialog
        current_user.apply_omniauth(omniauth)
        @authentication = current_user.authentications.create!(authparams) # Link to existing user
        flash[:notice] = "Yay! You're now connected to RecipePower through #{@authentication.provider_name}."
      end
      url_to = origin_url
    elsif @authentication
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}. Welcome back, #{@authentication.user.handle}!"
      sign_in @authentication.user, :event => :authentication
      response_service.amend originator
      url_to = after_sign_in_path_for(@authentication.user)
    # This is a new authentication (not previously linked to a user) and there is
    # no current user to link it to. It's possible that the authentication will come with
    # an email address which we can use to log the user in.
    elsif user
      user.apply_omniauth(omniauth)
      @authentication = user.authentications.create!(authparams) # Link to existing user
      sign_in user, :event => :authentication
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}. Nice to see you again, #{user.handle}!"
      response_service.amend originator
      url_to = after_sign_in_path_for(user)
    end
    # We haven't managed to get the user signed in by other means, but we still have an authorization
    if !(current_user || user)  # Failed login not because of failed invitation
      # The email didn't come in the authorization, so we now need to
      # discriminate between an existing user(and have them log in)
      # and a new user (and have them sign up). Time to throw the problem
      # over to the user controller, providing it with the authorization.
      session[:omniauth] = omniauth.except('extra')
      flash[:notice] = "Hmm, apparently that service isn't linked to your account. If you log in by other means (perhaps you need to create an account?), you can link that service in Sign-In Services"
      url_to = originator || new_user_session_path
    end
    # response_service.amend origin_url # Amend response expectations according to the originating URL
    render 'callback', :layout => false, :locals => { url_to: url_to }
  end

  def destroy
    @authentication = Authentication.find(params[:id])
    @authentication.destroy
    flash[:notice] = "Okay, no more #{@authentication.provider_name} authentication for you!"
    respond_to do |format|
      format.html {
        redirect_to authentications_url, :status => 303
      }
      format.json {
        redirect_to authentications_url, :status => 303
      }
      format.js {
        render action: "destroy", locals: {provider: @authentication.provider}
      }
    end
  end
end

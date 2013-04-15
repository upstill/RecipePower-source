require './lib/controller_utils.rb'
require 'uri'
  
class AuthenticationsController < ApplicationController
  
  # Edge case: we may get here in the course of authorizing collecting a recipe, in 
  # which case we forget about handling it in the embedded iframe: remove the "area=at_top" 
  # and "layout=injector" query parameters
  def strip_query(url)
    if url
      uri = URI url
      return url unless uri.query
      uri.query = uri.query.split('&').delete_if { |p| p.match(/^(area|layout)=/) }.join '&'
      uri.to_s
    end
  end
  
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
    flash[:notice] = "Sorry, authentication failed."
    @after_sign_in_url = nil # authentications_url
    if session[:original_uri]
      uri = URI session[:original_uri]
      if uri.query
        uri.query.split('&').each do |qp| 
          if md = qp.match( /^recipe%5Burl%5D=(.*$)/ )
            @after_sign_in_url = URI.unescape md[1]
          end
        end
      end
      session.delete :original_uri
    end
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
    if @authentication = Authentication.find_by_provider_and_uid(omniauth['provider'], omniauth['uid'])
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}. Welcome back, #{@authentication.user.handle}!"
      # result = sign_in_and_redirect @authentication.user # , :bypass => true
      sign_in @authentication.user, :event => :authentication
      @after_sign_in_url = strip_query(session[:original_uri]) || after_sign_in_path_for(@authentication.user)
      render 'callback', :layout => false
    elsif current_user
      # Just adding an authentication method to the current user
      current_user.apply_omniauth(omniauth)
      @authentication = current_user.authentications.create!(authparams) # Link to existing user
      flash[:notice] = "Yay! You're now connected to RecipePower through #{@authentication.provider_name}."
      @after_sign_in_url = collection_url
      render 'callback', :layout => false
    # This is a new authentication (not previously linked to a user) and there is 
    # no current user to link it to. It's possible that the authentication will come with
    # an email address which we can use to log the user in.
    elsif (info = omniauth['info']) && (email = info['email']) && (user = User.find_by_email(email))
      user.apply_omniauth(omniauth)
      @authentication = user.authentications.create!(authparams) # Link to existing user
      sign_in user, :event => :authentication
      flash[:notice] = "Yay! Signed in with #{@authentication.provider_name}. Nice to see you again, #{user.handle}!"
      @after_sign_in_url = strip_query(session[:original_uri]) || after_sign_in_path_for(user)
      render 'callback', :layout => false
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
        session[:original_uri] = strip_query(session[:original_uri])
        @after_sign_in_url = users_identify_url
        render 'callback', :layout => false
        # redirect_to users_identify_url
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

class SessionsController < Devise::SessionsController
  
  # GET /resource/sign_in
  def new
    self.resource = build_resource(nil, :unsafe => true)
    clean_up_passwords(resource)
    respond_to do |format|
      format.html { respond_with(resource, serialize_options(resource)) }
      format.json { 
        flash.now[:alert] = "Sorry--didn't recognize your credentials."
        @area = params[:area] || "floating"
        rendered = with_format("html") {
          render_to_string "authentications/new", layout: false 
        }
        return render :json => {
          :success => false, 
          :code => rendered 
        }
      }
    end
  end

  def create
    resource = warden.authenticate!(:scope => resource_name, :recall => "#{controller_path}#new" ) # :failure)
    return sign_in_and_redirect(resource_name, resource)
  end
  
  def destroy
    super
    flash[:notice] = flash[:notice].sub("uhandle", resource.handle) if flash[:notice] && resource
  end
  
  def sign_in_and_redirect(resource_or_scope, resource=nil)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    resource ||= resource_or_scope
    sign_in(scope, resource) unless warden.user(scope) == resource
    if omniauth = session[:omniauth]
      # If there's an omniauth authentication waiting in the session, we got here because it needed to 
      # connect with this account. So do that.
      authparams = omniauth.slice('provider', 'uid')
      resource.apply_omniauth(omniauth) # Collect any user info from omniauth
      resource.authentications.create!(authparams) # Link to existing user
      notice = "Well done, #{resource.handle}! You're logged in, AND you can now log in with #{omniauth.provider.capitalize}.<br>(You can make changes to this in Sign-In Services.)"
      session.delete(:omniauth)
    else
      notice = "Welcome back, #{resource.handle}! (Logged in successfully.)"
    end
    # redirect_url = recall_capture || collection_path
    # redirect_to redirect_url, :notice => notice
    redirect_to after_sign_in_path_for(resource_or_scope), notice: notice
  end
 
  def failure
    return render:json => {:success => false, :errors => ["Login failed."]}
  end
end

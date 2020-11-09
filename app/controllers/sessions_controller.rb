class SessionsController < Devise::SessionsController
  # For some mysterious reason, accessing the current_user screws up the signin process.
  skip_before_action :set_current_user
  skip_before_action :verify_authenticity_token # , only: [:create]
  include Rails.application.routes.url_helpers
  # protect_from_forgery with: :null_session

  before_action :allow_iframe, only: :new
  before_action :require_no_authentication, only: :create
  after_action :restore_tokens, only: :destroy

  # Somehow require_no_authentication redirects to after_sign_in_path_for when the user is already logged in
  def require_no_authentication
    super unless current_user
  end

  # GET /resource/sign_in
  def new
    if current_user
      # flash[:notice] = "All signed in. Welcome back, #{current_user.handle}!"
      redirect_to after_sign_in_path_for(current_user), notice: "All signed in. Welcome back, #{current_user.handle}!"
    elsif response_service.format == :html && !response_service.injector?
      if blocked_request = params[:blocked]
        # This code is nasty, because recognize_path dies horribly on notifications
        begin
          controller = Rails.application.routes.recognize_path blocked_request
        rescue Exception => e
          uri = URI(blocked_request)
          if match = uri.path.match(%r{^/users/(\d*)/notifications/(\d*)/(\w*)$})
            controller = Users::NotificationsWithDeviseController
          end
        end
      end
      redir = controller.show_page(blocked_request) do |entity, args={}|
        polymorphic_path view_context.polymorphable(entity), args if entity
      end if controller.respond_to(:show_page)
      redirect_to redir.if_present || home_path
    else
      self.resource = resource_class.new # build_resource(nil, :unsafe => true)
      if u = params[:user] && params[:user][:id] && User.find_by_id(params[:user][:id])
        self.resource.username = u.username
        self.resource.fullname = u.fullname
        self.resource.login = u.username || u.email
      end
      r = resource
      clean_up_passwords r
      resource.remember_me = 1
      smartrender :action => :new
    end
  end

  def create
    if current_user
      logger.info "Creating Session for User ##{current_user.id}..."
      to = after_sign_in_path_for(current_user)
      logger.info "...and redirecting to '#{to}'"
      redirect_to to
    else
      begin
        resource = warden.authenticate!(:scope => resource_name, :recall => "#{controller_path}#new") # :failure)
        result = sign_in_and_redirect(resource_name, resource)
        return result
      rescue Exception => e
        # It's an error to get a login twice, but if there's already a user, we can just proceed as normal
        if current_user
          render nil
        else
          flash[:error] = 'Oops! Can\'t find those credentials in our records.' unless current_user
          render :errors, locals: {with_popup: false} # Report error as flash
        end
      end
    end
  end

  def destroy
    handle = current_user.handle
    redirect_path = after_sign_out_path_for(resource_name)
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    if signed_out && is_navigational_format?
      set_flash_message :notice, :signed_out
      flash[:notice] = flash[:notice].sub( 'uhandle', handle) if handle.present?
    end

    if signed_out
      logger.info "Resetting Session"
      reset_session
    end

    # We actually need to hardcode this as Rails default responder doesn't
    # support returning empty response on GET request
    respond_to do |format|
      format.all {
        head :no_content
      }
      format.json {
        render :redirect, locals: { path: redirect_path }
      }
      format.any(*navigational_formats) {
        redirect_to redirect_path, :method => "GET"
      }
    end
  end

  # When a user signs out, maintain pending invitation and notification tokens
  def restore_tokens
    response_service.restore_tokens
  end

  # Normally we go back to the home page, but if a notification is waiting, we go to its target (if any)
  def after_sign_out_path_for(resource)
    ((notification = response_service.pending_notification) && notification.present.referral_path.if_present) || super
  end

  def sign_in_and_redirect(resource_or_scope, resource=nil)
    logger.debug "sign_in_and_redirect: Signing in #{(resource||resource_or_scope).handle}; redirecting with..."
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
      notice = "Welcome back, #{resource.handle}! You are logged in to RecipePower."
    end
    logger.debug "sign_in_and_redirect: Signed in #{resource.handle}; redirecting with..."
    LoginEvent.post resource # Register the login
    response_service.invitation_token = nil # Clear the pending invitation
    redirect_to after_sign_in_path_for(resource_or_scope), notice: notice
  end
 
  def failure
    return render :json => {:success => false, :errors => ['Login failed.']}
  end
end

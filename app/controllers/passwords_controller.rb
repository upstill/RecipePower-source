class PasswordsController < Devise::PasswordsController
  before_filter :allow_iframe, only: :new
  # before_filter { @_area = params[:_area] || "" }

  def validate_token original_token
    reset_password_token = Devise.token_generator.digest(User, :reset_password_token, original_token)
    unless self.resource = User.find_by(:reset_password_token => reset_password_token)
      error = "Oh dear. That password reset has gone stale. If you'll identify yourself again we'll happily send you another."
      redirect_to new_user_password_path(:mode => :modal), { flash: { error: error } }
    end
    resource
  end
  
  # GET /resource/password/new
  def new
    # session[:on_tour] = true
    fh = view_context.flash_hash
    super
    resource.login = params[:user][:login] if params[:user]
    smartrender
  end

  def edit
    if resource = validate_token(params[:reset_password_token])
      super
      smartrender
    end
  end

  def update
    if validate_token(params[:user][:reset_password_token])
      resource.reset_password_token = params[:user][:reset_password_token]
      password = params[:user] ? params[:user][:password] : nil
      if password.blank? || (password.length < 4)
        flash[:error] = "To protect your account, a password needs to have at least four characters."
        smartrender :action => "edit"
      else
        super
      end
    end
  end

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    if successfully_sent?(resource)
      respond_to do |format|
        format.html { # This is for capturing a new recipe. The injector (capture.js) calls for this
          redirect_to root_path
        }
        format.json {
          # @_area = params[:_area]
          content = with_format("html") { render_to_string "alerts/popup", layout: false }
          render json: { dlog: content }
        }
      end
    else
      error = "Hmm, we don't seem to have any user by that name (or email). Could you try again?"
      redirect_to new_user_password_path(:mode => response_service.mode, user: { login: params[:user][:login] }),
                  { :flash => { :error => error } }
    end
  end
end

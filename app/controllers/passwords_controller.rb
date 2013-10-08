require './lib/controller_utils.rb'
class PasswordsController < Devise::PasswordsController
  # before_filter { @area = params[:area] || "" }
  
  # GET /resource/password/new
  def new
    session[:on_tour] = true
    if request.format == "application/json"
      self.resource = resource_class.new()
      respond_with resource do |format|
        # format.html { render :partial => "registrations/form" }
        format.json { 
          render json: { 
                    dlog: with_format("html") { render_to_string :new, layout: false }
                  }
        }
      end
    else
      super
    end
  end
  
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    session[:on_tour] = true
    if successfully_sent?(resource)
      respond_to do |format|
        format.html { # This is for capturing a new recipe. The injector (capture.js) calls for this
          redirect_to home_path
        }
        format.json {
          # @area = params[:area]
          content = with_format("html") { render_to_string "alerts/popup", layout: false }
          render json: { dlog: content }
        }
      end
    else
      # respond_with resource
      resource_errors_to_flash_now resource, preface: "Sorry, can't reset password"
      respond_to do |format|
        format.html { redirect_to home_path, notice: "Sorry, can't reset password" }
        format.json { 
          # @area = params[:area]
          rendered = with_format("html") { render_to_string :new, layout: false }
          render :json => {
            :success => false, 
            :dlog => rendered 
          }
        }
      end
    end
  end
end

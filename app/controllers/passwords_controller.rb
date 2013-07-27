require './lib/controller_utils.rb'
class PasswordsController < Devise::PasswordsController
  before_filter { @area = params[:area] || "" }
  
  # GET /resource/password/new
  def new
    if request.format == "application/json"
      build_resource({})
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
    if successfully_sent?(resource)
      respond_to do |format|
        format.html { # This is for capturing a new recipe. The injector (capture.js) calls for this
          respond_with({}, :location => after_sending_reset_password_instructions_path_for(resource_name))
        }
        format.json {
          @area = params[:area]
          content = with_format("html") { render_to_string "alerts/popup", layout: false }
          render json: { dlog: content }
        }
      end
    else
      # respond_with resource
      resource_errors_to_flash_now resource, preface: "Sorry, can't reset password"
      respond_to do |format|
        format.html { render controller: :pages, action: :home }
        format.json { 
          @area = params[:area]
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
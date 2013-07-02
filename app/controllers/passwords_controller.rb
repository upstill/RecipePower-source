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
          render json: { done: true }
        }
      end
    else
      resource_errors_to_flash_now resource, preface: "Sorry, can't reset password"
      respond_with resource
    end
  end
=begin
    respond_to do |format|
      format.html { super }
      format.json { 
        debugger
        @area = params[:area]
        rendered = with_format("html") {
          render_to_string :new, layout: false 
        }
        render :json => {
          :success => false, 
          :code => rendered 
        }
      }
    end
=end
end
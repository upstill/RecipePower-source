require './lib/controller_utils.rb'
class PasswordsController < Devise::PasswordsController
  before_filter { @area = params[:area] || "" }
  
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
      flash_errors_now resource, "Sorry, can't reset password"
      respond_with(resource)
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
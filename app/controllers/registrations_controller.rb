class RegistrationsController < Devise::RegistrationsController
    before_filter :authenticate_user!, :except => [:show, :index]
    respond_to :html, :json
    def create
      # We can be coming from users#identify on the 'existing user' form
      if params[:commit] == "Go"
          if @user = User.find_by_email(params[:user][:email])
              if omniauth = session[:omniauth]
                @user.apply_omniauth(omniauth)
                @user.authentications.build(omniauth.slice('provider','uid'))
                @user.valid?
              end
              sign_in_and_redirect(:user, @user)
          else # No such user found
              redirect_to users_identify_url, :notice => "Sorry, we don't have any records of an '#{params[:user][:email]}'."
          end
      else
        if request.format == "application/json"
          build_resource

          if resource.save
            if resource.active_for_authentication?
              # set_flash_message :notice, :signed_up if is_navigational_format?
              sign_up(resource_name, resource)
              respond_with resource do |format|
                format.json { 
                  render json: { 
                            dlog: with_format("html") { render_to_string :partial => "users/dialog_step2" }
                          }
                }
              end
            else
              set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_navigational_format?
              expire_session_data_after_sign_in!
              respond_with resource, :location => after_inactive_sign_up_path_for(resource)
            end
          else
            clean_up_passwords resource
            respond_with resource do |format|
              # format.html { render :partial => "registrations/form" }
              format.json { 
                render json: { 
                          replacements: [
                            ["form[action='/users']", with_format("html") { render_to_string :partial => "registrations/form" }]
                          ]
                        }
              }
            end
          end
        else
          super
        end
        session[:omniauth] = nil unless @user.new_record?
      end
    end
    
    def new
        super
    end

    private

    def build_resource(*args)
      super
      if omniauth = session[:omniauth]
        @user.apply_omniauth(omniauth)
        @user.authentications.build(omniauth.slice('provider','uid'))
        @user.valid?
      end
    end
    
    # The path used after sign up. You need to overwrite this method
    # in your own RegistrationsController.
    def after_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end
end

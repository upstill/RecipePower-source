require './lib/uri_utils.rb'

class RegistrationsController < Devise::RegistrationsController
    before_filter :authenticate_user!, :except => [:show, :index]
    respond_to :html, :json
    
    def edit
      response_service.user = (params[:id] && User.find(params[:id])) || current_user
      smartrender 
    end
    
    def create
      # We can be coming from users#identify on the 'existing user' form
      if params[:commit] == "Go"
          if response_service.user = User.find_by_email(params[:user][:email])
              if omniauth = session[:omniauth]
                response_service.user.apply_omniauth(omniauth)
                response_service.user.authentications.build(omniauth.slice('provider','uid'))
                response_service.user.valid?
              end
              sign_in_and_redirect(:user, response_service.user)
          else # No such user found
              redirect_to users_identify_url, :notice => "Sorry, we don't have any records of an '#{params[:user][:email]}'."
          end
      else
          build_resource params[:user]
          resource.extend_fields
          if resource.save
            if resource.active_for_authentication?
              # set_flash_message :notice, :signed_up if is_navigational_format?
              sign_up(resource_name, resource)
              RpMailer.welcome_email(resource).deliver unless Rails.env.staging?
              redirect_to after_sign_up_path_for(resource)
            else
              set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_navigational_format?
              expire_session_data_after_sign_in!
              respond_with resource, :location => after_inactive_sign_up_path_for(resource)
            end
          else
            clean_up_passwords resource
            respond_with resource do |format|
              format.html { }
              format.json { 
                render json: { 
                          replacements: [
                            ["form.new_user", with_format("html") { render_to_string partial: "registrations/form" }]
                          ]
                        }
              }
            end
          end
        session[:omniauth] = nil unless response_service.user.new_record?
      end
    end

    def new
      response_service.omniauth_pending(params[:clear_omniauth])
      build_resource({})
      smartrender action: "new", locals: { header: params[:header] }
    end

    # PUT /resource
    # We need to use a copy of the resource because we don't want to change
    # the current user in place.
    def update
      account_update_params = devise_parameter_sanitizer.sanitize(:account_update)
      # required for settings form to submit when password is left blank
      if account_update_params[:password].blank?
        account_update_params.delete("password")
        account_update_params.delete("password_confirmation")
      end

      self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
      prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)
      if resource.update_attributes(account_update_params) # resource.update_with_password(resource_params)
        if is_navigational_format?
          flash_key = update_needs_confirmation?(resource, prev_unconfirmed_email) ?
            :update_needs_confirmation : :updated
          set_flash_message :notice, flash_key
        end
        sign_in resource_name, resource, :bypass => true
        respond_with(resource) do |format|
          format.html { redirect_to after_update_path_for(resource) }
          format.json { render :json => { done: true }.merge( view_context.flash_notify(true) ) }
        end
      else
        clean_up_passwords resource
        response_service.user = resource
        smartrender :action => "edit"
      end
    end

    private

    # Signs in a user on sign up. You can overwrite this method in your own
    # RegistrationsController.
    def sign_up(resource_name, resource)
      super
      (resource.class.to_s+"Services").constantize.new(resource).sign_up
    end

    def build_resource(*args)
      super
      if omniauth = session[:omniauth]
        response_service.user.apply_omniauth(omniauth)
        response_service.user.authentications.build(omniauth.slice('provider','uid'))
        response_service.user.valid?
      end
    end

    # The path used after sign up. You need to overwrite this method
    # in your own RegistrationsController.
    def after_sign_up_path_for(resource)
      defer_welcome_dialogs
      # Process any pending notifications
      after_sign_in_path_for resource
    end
    
    def user_root_path
      collection_path
    end
end

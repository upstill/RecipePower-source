require './lib/uri_utils.rb'

class RegistrationsController < Devise::RegistrationsController
    before_filter :authenticate_user!, :except => [:show, :index]
    respond_to :html, :json
    
    def edit
      @user = (params[:id] && User.find(params[:id])) || current_user
      # dialog_boilerplate "edit", "floating"
      smartrender area: "floating"
    end
    
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
        # if request.format == "application/json"
          build_resource params[:user]
          if resource.save
            if resource.active_for_authentication?
              # set_flash_message :notice, :signed_up if is_navigational_format?
              sign_up(resource_name, resource)
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
        # else
          # super
        # end
        session[:omniauth] = nil unless @user.new_record?
      end
    end

    def new
      response_service.omniauth_pending(params[:clear_omniauth])
      build_resource({})
      smartrender action: "new"
    end

    # PUT /resource
    # We need to use a copy of the resource because we don't want to change
    # the current user in place.
    def update
      self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
      prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)
      if resource.update_with_password(resource_params)
        if is_navigational_format?
          flash_key = update_needs_confirmation?(resource, prev_unconfirmed_email) ?
            :update_needs_confirmation : :updated
          set_flash_message :notice, flash_key
        end
        sign_in resource_name, resource, :bypass => true
        respond_with(resource) do |format|
          format.html { redirect_to after_update_path_for(resource) }
          format.json { render :json => { done: true } }
        end
      else
        clean_up_passwords resource
        @user = resource
        # dialog_boilerplate "edit", "floating"
        smartrender :action => "edit", area: "floating"
        # respond_with resource
      end
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
      assert_popup "starting_step2?context=signup", after_sign_in_path_for(resource)
    end
    
    def user_root_path
      collection_path
    end
end

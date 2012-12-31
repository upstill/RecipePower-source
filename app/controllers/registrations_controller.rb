class RegistrationsController < Devise::RegistrationsController
    before_filter :authenticate_user!, :except => [:show, :index]
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
          super
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
end

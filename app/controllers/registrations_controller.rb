class RegistrationsController < Devise::RegistrationsController
    before_filter :authenticate_user!, :except => [:show, :index]
    def create
        debugger
      # We can be coming from users#identify on the 'existing user' form
      if @user = User.find_by_email(params[:user][:email])
          if omniauth = session[:omniauth]
            @user.apply_omniauth(omniauth)
            @user.authentications.build(omniauth.slice('provider','uid'))
            @user.valid?
          end
          sign_in_and_redirect(:user, @user)
      else
          super
          session[:omniauth] = nil unless @user.new_record?
      end
    end
    
    def new
        debugger
        super
    end

    private

    def build_resource(*args)
      super
      debugger
      if omniauth = session[:omniauth]
        @user.apply_omniauth(omniauth)
        @user.authentications.build(omniauth.slice('provider','uid'))
        @user.valid?
      end
    end
end

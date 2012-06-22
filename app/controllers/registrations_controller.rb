class RegistrationsController < Devise::RegistrationsController
    def create
      super
      session[:omniauth] = nil unless @user.new_record?
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

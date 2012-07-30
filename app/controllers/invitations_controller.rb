class InvitationsController < Devise::InvitationsController
    # GET /resource/invitation/accept?invitation_token=abcdef
    def edit
      if params[:invitation_token] && self.resource = resource_class.to_adapter.find_first( :invitation_token => params[:invitation_token] )
        session[:invitation_token] = params[:invitation_token]
        render :edit
      else
        set_flash_message(:alert, :invitation_token_invalid)
        redirect_to after_sign_out_path_for(resource_name)
      end
    end

    # PUT /resource/invitation
    def update
      self.resource = resource_class.accept_invitation!(params[resource_name])

      if resource.errors.empty?
        RpMailer.invitation_accepted_email(resource).deliver
        session[:invitation_token] = nil
        set_flash_message :notice, :updated
        sign_in(resource_name, resource)
        respond_with resource, :location => after_accept_path_for(resource)
      else
        respond_with_navigational(resource){ render :edit }
      end
    end
    
    def after_accept_path_for resource
        welcome_path
    end
end

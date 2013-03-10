class InvitationsController < Devise::InvitationsController
    
    def after_invite_path_for(resource)
        collection_path
    end
    
    # GET /resource/invitation/new
    def new
      build_resource
      self.resource.invitation_issuer = current_user.fullname.blank? ? current_user.handle : current_user.fullname
      current_user.handle
      render :new
    end
    
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
    
    # POST /resource/invitation
    def create
      email = params[resource_name][:email].downcase
      begin
        self.resource = resource_class.invite!(params[resource_name], current_inviter)
      rescue Exception => e
        debugger
        self.resource = nil
      end
      debugger
      if resource && resource.errors.empty? # Success!
        set_flash_message :notice, :send_instructions, :email => self.resource.email
        respond_with resource, :location => after_invite_path_for(resource)
      elsif !resource
          if e.class == ActiveRecord::RecordNotUnique
            other = User.find_by_email email
            flash[:notice] = "What do you know? '#{other.handle}' has already been invited/signed up."
          else
            error = "Sorry, can't create invitation for some reason."
            if e
              e.to_s.split("\n").each { |line| 
                error << "\n"+line if (line =~ /DETAIL:/)
              }
            end
            flash[:error] = error
          end
          redirect_to collection_path
      elsif resource.errors[:email] 
        if(other = User.where(email: resource.email).first)
          # HA! request failed because email exists. Forget the invitation, just make us friends.
          id = other.email 
          id = other.handle if id.blank?
          id << " (aka #{other.handle})" if (other.handle != id)
          if current_inviter.followee_ids.include? other.id
              notice = "#{id} is already on RecipePower--and a friend of yours."
          else
              current_inviter.followees << other
              current_inviter.save
              notice = "But #{id} is already on RecipePower! Oh happy day!! <br>(We've gone ahead and made them your friend.)".html_safe
          end
          redirect_to collection_path, :notice => notice
        else # There's a resource error on email, but not because the user exists: go back for correction
          render :new
        end
      else
        respond_with_navigational(resource) { render :new }
      end
    end

    # PUT /resource/invitation
    def update
      self.resource = resource_class.accept_invitation!(params[resource_name])

      if resource.errors.empty?
        RpMailer.welcome_email(resource).deliver
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

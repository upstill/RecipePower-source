require 'token_input.rb'
require 'string_utils.rb'

class InvitationsController < Devise::InvitationsController
    
    def after_invite_path_for(resource)
        collection_path
    end
    
    def splitstr(str, ncols=80)
      str = HTMLEntities.new.decode(str)
      out = []
      line = ""
      str.split(/\s+/).each do |word|
        word << " "
        if (line.length + word.length) >= ncols
          out << line
          line = word
        else
          line << word
        end
      end
      out << line if line.length > 0
      out
    end   
     
    # GET /resource/invitation/new
    def new
      build_resource
      resource.shared_recipe = params[:recipe_id]
      @recipe = resource.shared_recipe && Recipe.find(resource.shared_recipe)
      self.resource.invitation_issuer = current_user.fullname.blank? ? current_user.handle : current_user.fullname
      dialog_boilerplate(@recipe ? :share : :new)
    end
    
    # GET /resource/invitation/accept?invitation_token=abcdef
    def edit
      if params[:invitation_token] && self.resource = resource_class.to_adapter.find_first( :invitation_token => params[:invitation_token] )
        session[:invitation_token] = params[:invitation_token]
        dialog_boilerplate :edit
      else
        set_flash_message(:alert, :invitation_token_invalid)
        redirect_to after_sign_out_path_for(resource_name)
      end
    end
    
    # POST /resource/invitation
    def create
      # If dialog has no invitee_tokens, get them from email field
      params[resource_name][:invitee_tokens] = params[resource_name][:invitee_tokens] ||
        params[resource_name][:email].split(',').collect { |email| %Q{'#{email.downcase.strip}'} }.join(',')
      # Check email addresses in the tokenlist for validity
      @user = User.new params[resource_name]
      for_sharing = @user.shared_recipe && true
      err_address = @user.invitee_tokens.detect do |token|
        token.kind_of?(String) && !(token =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i) 
      end
      if err_address # if there's an invalid email, go back to the user
        @user.errors.add :invitee_tokens, "'#{err_address}' doesn't look like an email address."
        @recipe = for_sharing && Recipe.find(@user.shared_recipe)
        dialog_boilerplate(for_sharing ? :share : :new)
        return
      end
      params[resource_name][:invitation_message] = 
        splitstr( params[resource_name][:invitation_message], 100) # Format the message for text
        
      messages = [] # This will be an array of messages to report back to the user
      popup = nil
      
      # Now that the invitee tokens are "valid", send mail to each
      breakdown = UserServices.new(@user).analyze_invitees(current_user)
      friend_nodes = nil
      if breakdown[:new_friends].count > 0
        friend_nodes = breakdown[:new_friends].collect { |nf| 
          @node = current_user.add_followee nf 
          with_format("html") { render_to_string :partial => "collection/node" } 
        }
      end
      build_resource
      
      # Do inviations and/or shares, as appropriate
      failures = []
      invited = []
      # breakdown[:to_invite] is the list of complete outsiders who need invitations as well as shares
      breakdown[:to_invite].each do |invitee|
        begin
          pr = params[resource_name]
          pr[:email] = invitee.downcase
          pr[:skip_invitation] = true # Hold off on invitation so we can redirect to share, as nec.
          @resource = self.resource = resource_class.invite!(pr, current_inviter)
          @resource.invitation_sent_at = Time.now.utc
          @resource.save(validate: false) # ...because the invitee doesn't have a handle yet
          @resource.issue_instructions(for_sharing ? :share_instructions : :invitation_instructions)
          invited << @resource
        rescue Exception => e
          failures.push({ email: invited.pop, error: e.to_s })
          self.resource = nil
        end
      end
      what_to_send = for_sharing ? "a sharing notice" : "an invitation"
      unless (emails = invited.map(&:email)).empty? # New invitations
        if (emails.count > 1) 
          subj_verb = what_to_send.sub(/^[^\s]*\s*/, '').capitalize+"s are winging their way"
        else
          subj_verb = what_to_send.capitalize+" is winging its way"
        end
        popup = "Yay! #{subj_verb} to "+liststrs(emails)
      end
      unless failures.empty?
        what_to_send = what_to_send.sub(/^[^\s]*\s*/, '')+"s"
        messages << "Couldn't send #{what_to_send} to:"
        messages << failures.collect { |f| "<li>#{f.email}: #{f.error}</li>" }.join+"</ul>"
      end
      
      if for_sharing
        breakdown[:redundancies].each do |red|
          # Existing friend: send share notice
        end
        pending = [] # Invited but not yet confirmed
        new_friends = [] # Newly-added friends (member's share notice sent)
        invited = [] # New invitations (non-member share notice sent)
      else
        unless (handles = breakdown[:redundancies].map(&:handle)).empty?
          messages << ["You're already friends with", liststrs(handles)].join(' ')
        end
        unless (emails = breakdown[:pending].map(&:email)).empty? # Invited but not yet confirmed
          messages << [
            liststrs(emails),
            (breakdown[:pending].count > 1 ? "have" : "has"),
            "already been invited but #{verb}n't logged in."
          ].join(' ')
        end
        unless (handles = breakdown[:new_friends].map(&:handle)).empty?
          messages << [ 
            liststrs(handles), 
            (breakdown[:new_friends].count > 1 ? "are" : "is"), 
            "already on RecipePower, so we've added them to your friends."
          ].join(' ')
        end
      end
      @recipe = for_sharing && Recipe.find(@user.shared_recipe)
      respond_to { |format|
        format.json { 
          response = { done: true }
          if friend_nodes
            response[:processorFcn] = "RP.content_browser.insert_or_select"
            response[:entity] = friend_nodes
          end
          # If there's a single message, report it in a popup, otherwise use an alert
          if messages.empty?
            response[:popup] = popup if popup
          else
            messages.unshift(popup) if popup
            response[:alert] = messages.join('<br>').html_safe
          end
          render json: response 
        }
      }
      return
      # Now we're done processing invitations, notifications and shares. Report back.
      ##################
      email = params[resource_name][:email].downcase
      if resource = User.where(email: email).first
        resource.errors[:email] << "We already have a user with that email address"
      else
        params[resource_name][:invitation_message] = 
          splitstr( params[resource_name][:invitation_message], 100)
        begin
          pr = params[resource_name]
          pr[:skip_invitation] = true
          @resource = self.resource = resource_class.invite!(pr, current_inviter)
          @resource.invitation_sent_at = Time.now.utc
          @resource.shared_recipe = Recipe.first.id
          @resource.save(validate: false) # ...because the invitee doesn't have a handle yet
          @resource.issue_instructions(:share_instructions)
        rescue Exception => e
          debugger
          self.resource = nil
        end
      end
      if resource && resource.errors.empty? # Success!
        set_flash_message :notice, :send_instructions, :email => self.resource.email
        notice = "Yay! An invitation is winging its way to #{resource.email}"
        respond_with resource, :location => after_invite_path_for(resource) do |format|
          format.json { render json: { done: true, alert: notice }}
        end
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
          dialog_boilerplate :new # redirect_to collection_path, :notice => notice
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
        session[:flash_popup] = "pages/starting_step2"
        respond_with resource, :location => assert_query( after_accept_path_for(resource), context: "signup")
      else
        respond_with_navigational(resource){ dialog_boilerplate :edit }
      end
    end
    
    def after_accept_path_for resource
      after_sign_in_path_for(resource) # welcome_path
    end
end

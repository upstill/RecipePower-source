require 'token_input.rb'
require 'string_utils.rb'
require 'uri_utils.rb'

class InvitationsController < Devise::InvitationsController
  # skip_before_action :verify_authenticity_token
  prepend_before_action :login_required, :except => [ :edit, :update ] # No invitations unless logged in!

  def after_invite_path_for(resource)
    default_next_path
  end

  # GET /resource/invitation/new
  # Create a new invitation--with or without a shared entity--and throw up a dialog to get email, message, etc.
  def new
    if (classname = params[:shared_class]).present?
      entity_name = params[:shared_name].if_present || classname.underscore.gsub('_',' ')
      @shared = classname.constantize.find_by id: params[:shared_id].to_i
      self.resource = resource_class.new invitation_message: @shared.comment || "Here's an interesting #{entity_name} I found on RecipePower. Have a look and tell me what you think."
      resource.shared_name = entity_name
      resource.shared = @shared
    else
      self.resource = resource_class.new
    end
    resource.invitation_issuer = current_user.polite_name
    if @shared
      smartrender :action => :share
    else
      smartrender
    end
  end

  # GET /resource/invitation/accept?invitation_token=abcdef
  # Accept an invitation
  def edit
    respond_to do |format|
      format.json {
        unless response_service.dialog?
          redirect_to default_next_path
        end
      }
      format.html {
        # Can't do anything till we render a page, so find a page to render, and depend on it to sort out the invitation
        redirect_to default_next_path
      }
    end
  end

  # POST /resource/invitation
  # Respond to dialog for issuing a share/invitation
  def create
    unless current_user
      logger.debug 'NULL CURRENT_USER in invitation/create without raising authenticity error'
      raise ActionController::InvalidAuthenticityToken
    end

    # If dialog has no invitee_tokens, get them from email field
    params[:user][:invitee_tokens] ||= params[:user][:email].split(',').collect { |email| %Q{'#{email.downcase.strip}'} }.join(',')
    # Check email addresses in the tokenlist for validity
    self.resource = User.new user_params # invite_resource
    @shared = resource.shared

    # It is an error to provide no email address or a bogus one
    err_address =
        resource.invitee_tokens.detect { |token|
          token.kind_of?(String) && !(token =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i)
        }
    if err_address || resource.invitee_tokens.empty? # if there's an invalid email, go back to the user
      resource.errors.add (@shared ? :invitee_tokens : :email),
                         err_address.blank? ?
                             'Can\'t send an invitation without an email to send it to!' :
                             "'#{err_address}' doesn't look like an email address."
      smartrender :action => (@shared ? :share : :new)
      return
    end

    # Now that the invitee tokens are syntactically "valid", post appropriate events for each
    breakdown = { # UserServices.new(resource).analyze_invitees(current_user)
        extant_friends:  [], # Current friends (member's share notice sent)
        new_friends:  [], # Newly-added friends (member's share notice sent)
        reinvited:  [], # Invited but not yet confirmed
        to_invite:  []
    }
    # Define a singleton method on the hash for reporting out the results
    def breakdown.report(which, selector = nil)
      if (items = self[which]).present?
        count = items.size
        items = liststrs(items.map(&selector)) if selector
        yield(items, count)
      end
    end
    resource.invitee_tokens.each do |invitee|
      # Convert tokens to users
      category =
      if u = invitee.is_a?(Fixnum) ? User.find(invitee) : User.find_by(email: invitee.downcase)
        # Existing user, whether signed up or not, friend or not
        u.invitation_message = user_params[:invitation_message]
        if current_user.followee_ids.include? u.id # Existing friend: redundant
          SharedEvent.post(current_user, @shared, u) if @shared
          :extant_friends
        elsif u.last_sign_in_at # The user needs no invitation (already signed in)
          SharedEvent.post(current_user, @shared, u) if @shared
          :new_friends
        else # User exists but hasn't signed in -> invitation is pending
          u.invite!(current_inviter) { |u| u.skip_invitation = true }
          InvitationSentEvent.post current_user, u, @shared, u.raw_invitation_token
          :reinvited
        end
      else
        # This is a new invitation/share to a new user
        up = user_params.clone
        up[:email] = invitee.downcase
        u = resource_class.invite!(up, current_user) { |u| u.skip_invitation = true }
        InvitationSentEvent.post current_user, u, @shared, u.raw_invitation_token
        :to_invite
      end
      breakdown[category] << u
    end

    # Recruit new friends (invitees who aren't currently friends)
    new_friend_ids = breakdown[:new_friends].map(&:id) - current_user.followee_ids
    if new_friend_ids.present?
      current_user.followee_ids = current_user.followee_ids + new_friends_ids
      current_user.save
    end

    what_to_send = @shared ? 'a sharing notice' : 'an invitation'
    # Messages to report back to the user
    popup =
        breakdown.report(:to_invite, :email) { |users, count|
          if count > 1
            subj_verb = what_to_send.sub(/^[^\s]*\s*/, '').capitalize + 's are winging their way'
          else
            subj_verb = what_to_send.capitalize + ' is winging its way'
          end
          %Q{Yay! #{subj_verb} to #{users}}
        }
    alerts = @shared ? [] : [ # Invitations only
        breakdown.report(:extant_friends, :handle) { |names, count|
          "You're already friends with #{names}." },
        breakdown.report(:reinvited, :email) { |names, count|
          verb = count > 1 ? 'have' : 'has'
          %Q{#{names} #{verb} already been invited but #{verb}n't accepted.}
        },
        breakdown.report(:new_friends, :handle) { |names, count|
          %Q{#{names} #{count > 1 ? 'are' : 'is'} already on RecipePower, so we've added them to your friends.}
        } ].compact

    respond_to { |format|
      format.json {
        response = {done: true}
        if (msgs = ((alerts || []) << popup.if_present).compact).present?
          response[alerts.present? ?  :alert : :popup] = msgs.join('<br>').html_safe
        end
        render json: response
      }
    }
  end

  # PUT /resource/invitation
  def update
    params[:user][:invitation_token] = response_service.invitation_token
    self.resource = resource_class.accept_invitation! user_params
    resource.password = resource.email if resource.password.blank?
    if resource.errors.empty?
      if resource.password == resource.email
        flash[:alert] = 'You didn\'t provide a password, so we\'ve set it to be the same as your email address. You might want to consider changing that in your Profile'
      end
      response_service.user = resource
      evt = InvitationAcceptedEvent.post resource, InvitationSentEvent.find_by_invitee(resource), resource.invited_by
      evt.notify :users, key: 'invitation_accepted_event.feedback', send_later: ResponseServices.has_worker? # !Rails.env.development?

      set_flash_message :notice, :updated
      sign_in(resource_name, resource)
      response_service.invitation_token = nil # Clear the invitation
      redirect_to after_accept_path_for(resource), status: 303
    else
      respond_with_navigational(resource) { smartrender :action => :edit, :mode => :modal }
    end
  end

  # When the user gets distracted by the recipe link in a sharing notice
  def divert
    InvitationDivertedEvent.post resource_class.find(params[:recipient]), resource_class.find(params[:sender])
    redirect_to CGI::unescape(params[:url])
  end

  def after_accept_path_for resource
    defer_welcome_dialogs
    after_sign_in_path_for resource
  end

  def resource_from_invitation_token
    session[:invitation_token] = params[:invitation_token] if params[:invitation_token]
  end

  # Override to allow inspection of invitation while logged in
  def require_no_authentication
    super unless params[:action] == 'edit'
  end

  def user_params
    params.require(:user).permit(:invitee_tokens, :email, :username, :password,
                                 :invitation_token, :invitation_issuer, :invitation_message,
                                 :shared_class, :shared_id, :shared_name)
  end

end

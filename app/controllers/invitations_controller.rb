require 'token_input.rb'
require 'string_utils.rb'
require 'uri_utils.rb'

class InvitationsController < Devise::InvitationsController
  # skip_before_filter :verify_authenticity_token
  prepend_before_filter :login_required, :except => [ :edit, :update ] # No invitations unless logged in!

  def after_invite_path_for(resource)
    default_next_path
  end

  # GET /resource/invitation/new
  # Create a new invitation--with or without a shared entity--and throw up a dialog to get email, message, etc.
  def new
    if (classname = params[:shared_class]).present?
      entity_name = params[:shared_name].if_present || classname.underscore.gsub('_',' ')
      @shared = classname.constantize.find_by id: params[:shared_id].to_i
      self.resource = resource_class.new invitation_message: current_user.comment_for(@shared) || "Here's an interesting #{entity_name} I found on RecipePower. Have a look and tell me what you think."
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
    resource_params = params[resource_name]

    # If dialog has no invitee_tokens, get them from email field
    resource_params[:invitee_tokens] ||= resource_params[:email].split(',').collect { |email| %Q{'#{email.downcase.strip}'} }.join(',')
    # Check email addresses in the tokenlist for validity
    self.resource = User.new resource_params # invite_resource
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
        u.invitation_message = resource_params[:invitation_message]
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
        u = resource_class.invite!(resource_params.merge(email: invitee.downcase), current_user) { |u| u.skip_invitation = true }
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
    return
    # Now we're done processing invitations, notifications and shares. Report back.
    ##################
    email = resource_params[:email].downcase
    if resource = User.where(email: email).first
      resource.errors[:email] << 'We already have a user with that email address'
    else
      resource_params[:invitation_message] =
          splitstr(resource_params[:invitation_message], 100)
      begin
        pr[:skip_invitation] = true
        resource = self.resource = resource_class.invite!(pr, current_inviter)
        resource.invitation_sent_at = Time.now.utc
        resource.save(validate: false) # ...because the invitee doesn't have a handle yet
        InvitationSentEvent.post current_inviter, resource, @shared
        # Formerly resource.issue_instructions(:share_instructions) (IS THIS NECESSARY?)
        resource.update_attribute :invitation_sent_at, Time.now.utc unless resource.invitation_sent_at
        resource.generate_invitation_token! unless resource.raw_invitation_token
        resource.send_devise_notification :share_instructions, resource.raw_invitation_token
      rescue Exception => e
        self.resource  = nil
      end
    end
    if resource && resource.errors.empty? # Success!
      set_flash_message :notice, :send_instructions_html, :email => resource.email
      notice = "Yay! An invitation is winging its way to #{resource.email}"
      respond_with resource, :location => after_invite_path_for(resource) do |format|
        format.json { render json: {done: true, alert: notice} }
      end
    elsif !resource
      if e.class == ActiveRecord::RecordNotUnique
        other = User.find_by_email email
        flash[:notice] = "What do you know? '#{other.handle}' has already been invited/signed up."
      else
        error = 'Sorry, can\'t create invitation for some reason.'
        if e
          e.to_s.split('\n').each { |line|
            error << '\n'+line if (line =~ /DETAIL:/)
          }
        end
        flash[:error] = error
      end
      redirect_to default_next_path
    elsif resource.errors[:email]
      if (other = User.where(email: resource.email).first)
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
        smartrender :action => :new
      else # There's a resource error on email, but not because the user exists: go back for correction
        render :new
      end
    else
      respond_with_navigational(resource) { render :new }
    end
  end

  # PUT /resource/invitation
  def update
    resource_params = params[resource_name]
    self.resource = resource_class.accept_invitation! resource_params
    resource.password = resource.email if resource.password.blank?
    if resource.errors.empty?
      if resource.password == resource.email
        flash[:alert] = 'You didn\'t provide a password, so we\'ve set it to be the same as your email address. You might want to consider changing that in your Profile'
      end
      response_service.user = resource
      evt = InvitationAcceptedEvent.post resource, resource.invited_by, InvitationSentEvent.find_by_invitee(resource)
      evt.notify :users, key: 'invitation_accepted_event.feedback', send_later: ResponseServices.has_worker? # !Rails.env.development?

      set_flash_message :notice, :updated
      sign_in(resource_name, resource)
      response_service.invitation_token = nil # Clear the invitation
      redirect_to after_accept_path_for(resource), status: 303
    else
      # respond_with_navigational(resource){ dialog_boilerplate :edit }
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

end

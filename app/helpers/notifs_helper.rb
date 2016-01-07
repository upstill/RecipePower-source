module NotifsHelper

  # To go with any page: present pending notifications (and invitations) in a modal atop
  def do_notifs
    handle_invitation_and_login
  end

  # Any pending invitation gets handled here, and also getting login credentials w/o an invitation
  def handle_invitation_and_login
    if !(response_service.invitation_token || current_user)
      # The simplest case: no invitation token, no current user
      # Simply present login options
      render 'notifs/panel'
    elsif response_service.invitation_token
      # Sort out a pending invitation, whether anyone is logged in or not
      handle_invitation 'notifs/panel'
    end
  end

  def handle_invitation partial
    if (invitee = response_service.pending_invitee) && !invitee.errors.any?
      # The pending invitation is valid
      it = response_service.invitation_token
      response_service.invitation_token = nil
      if current_user
        # ...but someone is already logged in!
        if current_user == invitee || current_user == invitee.aliased_to
          flash.now[:notice] = 'You\'ve already accepted this invitation!'
          render 'alerts/popup_modal'
        elsif params[:make_alias]
          invitee.aliased_to = current_user
          invitee.save
          flash.now[:notice] = "Invitation accepted; you're now following #{invitee.invitation_issuer}--and vice versa"
          render 'alerts/popup_modal'
        elsif current_user.follows? invitee
          flash.now[:notice] = "You're already following #{invitee.invitation_issuer}!"
          render 'alerts/popup_modal'
        else
          # Invitation is for another, not-yet-accepted 'user'; enquire if it's the same person
          render 'invitations/check_alias', invitee: invitee, invitation_token: it
        end
      else
        # Finally! Nobody logged in and invitation token is valid => render acceptance dialog
        invitee.extend_fields
        response_service.invitation_token = it # The token is still pending; if user chooses to sign in, it will be processed
        render partial, resource: invitee
      end
    else
      if current_user
        render 'alerts/popup_modal', alert_msg: 'Sorry, that invitation has expired (perhaps you accepted it?)'
      else
        # Bad invitation token => nullify the invitation and incorporate into panel
        invitee_error = flash.now[:alert] = 'Sorry, that invitation has expired. But do sign up!'
        render partial, invitee_error: invitee_error
      end
    end

  end
end


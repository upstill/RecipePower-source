module NotifsHelper

=begin
  # Pump pending notifications into flash notices
  def issue_notifications user
    notices = user.notifications_received.where(accepted: false).map(&:accept).join('<br>'.html_safe)
    flash[:success] = notices unless notices.blank?
  end
=end

  def invitation_acceptance_label
    response_service.pending_notification ? 'Take Share' : 'Accept Invite'
  end

  # To go with any page: present pending notifications (and invitations) in a modal atop
  def due_notifs
    if current_user
      # User logged in: check for notifications
      if notif = notifiable_notification
        render 'notifications/present', presenter: present(notif, current_user)
      end
    elsif response_service.invitation_token
      # Sort out a pending invitation, whether anyone is logged in or not
      handle_invitation 'notifs/panel', !response_service.notification_token
    else
      # The simplest case: no invitation token, no current user
      # Simply present login options
      render 'notifs/panel'
    end
  end

  def notifs_replacement
    [ 'div.notifs-holder', do_notifs ]
  end

  # To go with any page: provide the SignIn/SignUp/AcceptInvitation floater
  def do_notifs
    sections = [] # Accumulates the sections to be shown
    invitee = response_service.pending_invitee
    notif = response_service.pending_notification
    if @target = current_user
      # If there's a pending invitation
      if invitee
        # If it's for the current user
        if current_user.id == invitee.id
          # Invitation is redundant
          flash[:now] = "No invitation required: you're already logged in!"
          # Clear the invitation_token
        else # Invitation is for some other user
          # Post "please logout first" alert
          sections << OpenStruct.new(
              is_vis: true,
              partial: 'sessions/logout_panel',
              partial_locals: {message: 'That invitation is for someone else. Just log out if you\'d like to use it'}
          )
        end
        return render('notifs/panel', sections: sections, as_alert: true, wide: true)
      end

      # If there's a pending notification
      if notif
        # If the notification matches the current user
        if current_user.id == notif.target.id
          # All is well; clear the pending notification
          response_service.notification_token = nil # Clear the notification
          flash.now[:notice] = msg
        else # Notification is for some other user
          sections << OpenStruct.new(
              is_vis: true,
              exclusive: true,
              partial: 'sessions/logout',
              partial_locals: {message: 'That notification is for someone else. Just log out if you\'d like to see it'}
          )
        end
      end # User is logged in, pending items disposed of
      sections << OpenStruct.new(
          signature: 'notifications',
          title: 'Notifications',
          partial: 'notifs/notifications'
      )
      # if no current user, but there's a pending invitation
    else
      invitee_error =
      if invitee && invitee.errors.any?
        # Sort out a pending invitation
        # Bad invitation token => nullify the invitation and incorporate into panel
        response_service.invitation_token = nil # Clear invitation token
        invitee = nil  # Forget about the invitee
        flash.now[:alert] = 'Sorry, that invitation has expired. But do sign up!'
      end
      if invitee
        sections << OpenStruct.new(# Collect credentials
            signature: 'accept',
            is_vis: true,
            is_main: true,
            title: invitation_acceptance_label,
            exclusive: true,
            partial: 'devise/invitations/form', # 'notifs/accept_invitation',
            partial_locals: {resource: invitee, resource_name: 'user', invitee_error: invitee_error}.compact
        )
        sections << OpenStruct.new(# Sign In
            signature: 'signin',
            title: 'Sign In Otherwise',
            partial: 'notifs/signin'
        )
      else # No current user, no pending invitation (or invitation cancelled)
        # The simplest case: no invitation token, no current user
        # Simply present login options
        sections << OpenStruct.new(# Sign Up
            signature: 'signup',
            is_main: true,
            is_vis: !invitee_error.nil?,
            title: 'Sign Up',
            partial: 'registrations/options' # 'notifs/signup'
        )
        sections << OpenStruct.new(# Sign In
            signature: 'signin',
            title: 'Sign In',
            partial: 'notifs/signin'
        )
      end
    end
    render 'notifs/panel', sections: sections
  end

  # Deal with an invitation, rendering it to the given partial if there's action to be taken.
  # If no action is to be taken and advise is true, then provide an advisory alert
  def handle_invitation partial, advise=true
    if (invitee = response_service.pending_invitee) && !invitee.errors.any?
      # The pending invitation is valid
      it = response_service.invitation_token
      response_service.invitation_token = nil
      if current_user
        # ...but someone is already logged in!
        if current_user == invitee || current_user == invitee.aliased_to
          if advise
            flash.now[:notice] = 'You\'ve already accepted this invitation!'
            render 'alerts/popup_modal'
          end
        elsif params[:make_alias]
          invitee.aliased_to = current_user
          invitee.save
          if advise
            flash.now[:notice] = "Invitation accepted; you're now following #{invitee.invitation_issuer}--and vice versa"
            render 'alerts/popup_modal'
          end
        elsif current_user.follows? invitee
          if advise
            flash.now[:notice] = "You're already following #{invitee.invitation_issuer}!"
            render 'alerts/popup_modal'
          end
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
        if advise
          render 'alerts/popup_modal', alert_msg: 'Sorry, that invitation has expired (perhaps you accepted it?)'
        end
      else
        # Bad invitation token => nullify the invitation and incorporate into panel
        invitee_error = flash.now[:alert] = 'Sorry, that invitation has expired. But do sign up!'
        render partial, invitee_error: invitee_error
      end
    end

  end
end


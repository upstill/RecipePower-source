module NotifsHelper

  def do_notifs do_login
    if invitee = response_service.pending_invitee
      if invitee_error = invitee.errors.any?
        flash.now[:alert] = 'Sorry, that invitation has expired. But do sign up!'
        invitee = nil
      end
    end
    render 'notifs/panel', invitee: invitee, invitee_error: invitee_error
  end
end
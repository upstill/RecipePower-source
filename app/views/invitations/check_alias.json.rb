{
    dlog: with_format('html') { render 'invitations/check_alias', invitee: invitee, invitation_token: invitation_token }
}.to_json
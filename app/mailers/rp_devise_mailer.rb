
class RPDeviseMailer < Devise::Mailer  
  # require ActionView::Helpers::TagHelper
  helper :application # gives access to all helpers defined within `application_helper`.
  
  # Deliver an invitation email
  def sharing_invitation_instructions(record, opts={})
    @notification_token = opts[:notification_token] if opts[:notification_token]
     # optional arguments introduced in Devise 2.2.0, remove check once support for < 2.2.0 is dropped.
    if Gem::Version.new(Devise::VERSION.dup) < Gem::Version.new('2.2.0')
      devise_mail(record, :sharing_invitation_instructions)
    else
      devise_mail(record, :sharing_invitation_instructions, opts)
    end
  end
end

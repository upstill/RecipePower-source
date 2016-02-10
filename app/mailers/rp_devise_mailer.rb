
class RPDeviseMailer < Devise::Mailer  
  # require ActionView::Helpers::TagHelper
  helper :application # gives access to all helpers defined within `application_helper`.
  
  # Deliver an invitation email
  def sharing_invitation_instructions(record, raw_token, opts={})
    @notification_token = opts[:notification_token] if opts[:notification_token]
    @recipient = record
    @sender = record.invited_by
    # opts[:from] = "Ignatz from RecipePower <ignatz@recipepower.com>"
    # optional arguments introduced in Devise 2.2.0, remove check once support for < 2.2.0 is dropped.
    @invitation_event = RpEvent.post @sender,
                                     :invitation_sent,
                                     @recipient.shared,
                                     @recipient
    # Add an attachment for the shared entity's image, if available
    if (imgdata = @recipient.shared && @recipient.shared.imgdata).present?
      attachments['collectible_image'] = Base64.decode64(imgdata.sub(/^data:image\/png;base64,/,''))
    end
    if Gem::Version.new(Devise::VERSION.dup) < Gem::Version.new('2.2.0')
      devise_mail(record, :sharing_invitation_instructions)
    else
      devise_mail(record, :sharing_invitation_instructions, opts)
    end
  end
end

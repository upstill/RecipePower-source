require 'token_input.rb'
require 'string_utils.rb'
require 'uri_utils.rb'

class InvitationsController < Devise::InvitationsController
  # skip_before_filter :verify_authenticity_token

  def after_invite_path_for(resource)
    collection_path
  end

  # GET /resource/invitation/new
  def new
    self.resource = resource_class.new()
    resource.shared_recipe = params[:recipe_id]
    @recipe = resource.shared_recipe && Recipe.find(resource.shared_recipe)
    self.resource.invitation_issuer = current_user.fullname.blank? ? current_user.handle : current_user.fullname
    # dialog_boilerplate(@recipe ? :share : :new)
    smartrender @recipe ? :share : :new
  end

  # GET /resource/invitation/accept?invitation_token=abcdef
  def edit
    if defer_invitation
      session[:notification_token] = params[:notification_token] if params[:notification_token]   
      # dialog_boilerplate :edit, "page", redirect: home_path
      smartrender :edit, area: "page", redirect: home_path
    else
      set_flash_message(:alert, :invitation_token_invalid)
      redirect_to after_sign_out_path_for(resource_name)
    end
  end

  # POST /resource/invitation
  def create
    unless current_user
      logger.debug "NULL CURRENT_USER in invitation/create without raising authenticity error"
      raise ActionController::InvalidAuthenticityToken
    end
    # If dialog has no invitee_tokens, get them from email field
    params[resource_name][:invitee_tokens] = params[resource_name][:invitee_tokens] ||
      params[resource_name][:email].split(',').collect { |email| %Q{'#{email.downcase.strip}'} }.join(',')
    # Check email addresses in the tokenlist for validity
    @staged = User.new params[resource_name]
    for_sharing = @staged.shared_recipe && true
    err_address = @staged.invitee_tokens.detect do |token|
      token.kind_of?(String) && !(token =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i)
    end
    if err_address # if there's an invalid email, go back to the user
      @staged.errors.add (for_sharing ? :invitee_tokens : :email), "'#{err_address}' doesn't look like an email address."
      @recipe = for_sharing && Recipe.find(@staged.shared_recipe)
      self.resource = @staged
      # dialog_boilerplate(for_sharing ? :share : :new)
      smartrender for_sharing ? :share : :new
      return
    end

    alerts = [] # This will be an array of messages to report back to the user
    popups = []

    # Now that the invitee tokens are "valid", send mail to each
    breakdown = UserServices.new(@staged).analyze_invitees(current_user)
    self.resource = resource_class.new()
    # Do invitations and/or shares, as appropriate
    breakdown[:invited] = []
    breakdown[:failures] = []
    # breakdown[:to_invite] is the list of complete outsiders who need invitations as well as shares
    # breakdown[:pending] are invitees who haven't yet accepted
    (breakdown[:to_invite]+breakdown[:pending]).each do |invitee|
      # Fresh invitations to a genuine external user
      begin
        pr = params[resource_name]
        pr[:email] = (invitee.kind_of?(User) ? invitee.email : invitee).downcase
        pr[:skip_invitation] = true # Hold off on invitation so we can redirect to share, as nec.
        @resource = self.resource = resource_class.invite!(pr, current_inviter)
        @resource.invitation_sent_at = Time.now.utc
        if for_sharing
          @notification = @resource.post_notification(:share_recipe, current_inviter, what: params[resource_name][:shared_recipe])
          @resource.save(validate: false) # ...because the invitee doesn't have a handle yet
          @resource.issue_instructions(:sharing_invitation_instructions, notification_token: @notification.notification_token)
        else
          @resource.save(validate: false) # ...because the invitee doesn't have a handle yet
          @resource.issue_instructions(:invitation_instructions)
        end
        breakdown[:invited] << @resource
        #        rescue Exception => e
        #          breakdown[:failures].push({ email: invitee.email, error: e.to_s })
        #          self.resource = nil
      end
    end
    what_to_send = for_sharing ? "a sharing notice" : "an invitation"
    popups <<
    breakdown.report(:invited, :email) { |names, count|
      subj_verb = (count > 1) ?
      (what_to_send.sub(/^[^\s]*\s*/, '').capitalize+"s are winging their way") :
      (what_to_send.capitalize+" is winging its way")
      %Q{Yay! #{subj_verb} to #{names}}
         }
      alerts <<
      breakdown.report(:failures) { |items, count|
        what_to_send = what_to_send.sub(/^[^\s]*\s*/, '')+"s" if count > 1
        "Couldn't send #{what_to_send} to:"+
        "<ul>" + items.collect { |item| "<li>#{item[:email]}: #{item[:error]}</li>" }.join + "</ul>"
      }

      if for_sharing
        # All categories of user get notified of the share
        (breakdown[:new_friends]+breakdown[:redundancies]).each do |sharee|
          # Mail generic share notice with action button to collect recipe
          # Cook Me Later: add to collection
          sharee.invitation_message = params[:user][:invitation_message]
          sharee.save
          sharee.notify(:share_recipe, current_user, what: params[resource_name][:shared_recipe] )
          breakdown[:invited] << sharee
        end
      else
        alerts << [
          breakdown.report(:redundancies, :handle) { |names, count|
          "You're already friends with #{names}." },
          breakdown.report(:pending, :email) { |names, count|
            verb = count > 1 ? "have" : "has"
            %Q{#{names} #{verb} already been invited but #{verb}n't accepted.}
               },
            breakdown.report(:new_friends, :handle) { |names, count|
              %Q{#{names} #{count > 1 ? "are" : "is"} already on RecipePower, so we've added them to your friends.}
                 }
              ]
              end
              @recipe = for_sharing && Recipe.find(@staged.shared_recipe)
              respond_to { |format|
                format.json {
                  response = { done: true }
                  if breakdown[:new_friends].count > 0
                    # New friends must be added to the Browser list
                    response[:entity] = breakdown[:new_friends].collect { |nf|
                      @node = current_user.add_followee nf
                      @browser = current_user.browser
                      with_format("html") { render_to_string :partial => "collection/node" }
                    }
                    response[:processorFcn] = "RP.content_browser.insert_or_select"
                  end
                  # If there's a single message, report it in a popup, otherwise use an alert
                  if (alerts = alerts.flatten.compact).empty?
                    response[popups.count == 1 ? :popup : :alert] = popups.join('<br>').html_safe unless popups.empty?
                  else
                    response[:alert] = (popups+alerts).compact.join('<br>').html_safe
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
                  # dialog_boilerplate :new # redirect_to collection_path, :notice => notice
                  smartrender :new # redirect_to collection_path, :notice => notice
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
                  session.delete :invitation_token
                  set_flash_message :notice, :updated
                  sign_in(resource_name, resource)
                  session[:flash_popup] = "pages/starting_step2_modal"
                  respond_with resource, :location => assert_query( after_accept_path_for(resource), context: "signup")
                else
                  # respond_with_navigational(resource){ dialog_boilerplate :edit }
                  respond_with_navigational(resource){ smartrender :edit }
                end
              end

              def after_accept_path_for resource
                after_sign_in_path_for(resource) # welcome_path
              end
              end

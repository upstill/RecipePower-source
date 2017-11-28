class CustomFailure < Devise::FailureApp

  # In failing due to an authentication error, we redirect to a page
  # which will allow for the login dialog. The general case is the app
  # home page. Exceptions:
  #   Notifications depend on the generating event:
  #     * SharedEvent goes to the page for the entity shared
  # which depends on the source of the error.
  def redirect_url
    new_user_session_url blocked: request.env['REQUEST_PATH']
  end

  # You need to override respond to eliminate recall
  def respond
    if http_auth?
      http_auth
    else
      redirect
    end
  end
end
class RedirectController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :go ]

  # The redirect controller has the sole purpose of turning a JSON or JS request
  # into an HTML request by sending a response that redirects to a page
  def go
    flash.keep # Hold flash for the redirect
    session[:goto] = to = (params[:to].sub /^"?([^"]*)"?$/, '\\1') # params[:to].sub(/^"/, '').sub(/"$/, '')
    respond_to { |format|
      # Decode the URL embedded in the :to parameter, removing enclosing quotes
      format.json {
        render json: { redirect: to }  # Strip enclosing quotes, if any
      }
    }
  end
end

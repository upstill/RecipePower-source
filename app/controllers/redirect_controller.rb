class RedirectController < ApplicationController

  # The redirect controller has the sole purpose of turning a JSON or JS request
  # into an HTML request by sending a response that redirects to a page
  def go
    respond_to { |format|
      # Decode the URL embedded in the :to parameter, removing enclosing quotes
      format.json { render json: { redirect: URI.decode(params[:to].sub /^"?([^"]*)"?/, '\\1') }}
    }
  end
end

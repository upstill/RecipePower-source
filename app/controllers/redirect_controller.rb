class RedirectController < ApplicationController

  # The redirect controller has the sole purpose of turning a JSON or JS request
  # into an HTML request by sending a response that redirects to a page
  def go
    respond_to { |format|
      format.json { render json: { redirect: params[:to] }}
    }
  end
end

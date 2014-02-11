class RedirectController < ApplicationController

  # The redirect controller has the sole purpose of turning a JSON or JS request
  # into an HTML request by sending a response that redirects to a page
  def go
    flash.keep
=begin
    uri = URI(params[:to].sub /^"?([^"]*)"?/, '\\1') # Strip enclosing quotes, if any
    if notice = view_context.flash_popup
      new_query_ar = URI.decode_www_form(uri.query||[]) << ["notice", notice]
      uri.query = URI.encode_www_form(new_query_ar)
    end
=end
    respond_to { |format|
      # Decode the URL embedded in the :to parameter, removing enclosing quotes
      format.json {
        render json: { redirect: (params[:to].sub /^"?([^"]*)"?/, '\\1') }  # Strip enclosing quotes, if any
      }
    }
  end
end

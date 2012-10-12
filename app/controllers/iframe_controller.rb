# The sole purpose of this controller is to receive the dimensions of an iframe
# (by making a json request) and report it back with a Javascript request. The 
# latter returns a script that calls a function passed as the :callback parameter,
# passing it an object with :height and :width properties.
class IframeController < ApplicationController
  def create
      respond_to do |format|
          # Accept an iframe spec from the client and store it in the session
          format.json {
              session[:ifr] = params[:ifr]
              session[:ifr][:url] = params[:url]
              render json: { }
          }
          # Return the previously-stored spec, IFF the url parameter matches (so
          # we're not responding before the spec arrives)
          format.js {
              @dims = session[:ifr] if (params[:url] == session[:ifr][:url])
              render
          }
      end
  end

end

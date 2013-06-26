class PagesController < ApplicationController
  # filter_access_to :all
  respond_to :html, :json
  def home
    session.delete :on_tour # Tour's over!
  	@Title = "Home"
    @auth_context = :manage
  end

  def contact
  	@Title = "Contact"
  end

  def about
  	@Title = "About"
  end

  def faq
    @Title = "FAQ"
  end
  
  def popup
    respond_with do |format|
      format.json { 
        render json: {
          dlog: with_format("html") { render_to_string :partial => params[:name] }
        }
      }
    end
  end

end

class PagesController < ApplicationController
  # filter_access_to :all
  respond_to :html, :json
  def home
  	@Title = "Home"
  	@nav_current = :home
    @auth_context = :manage
  end

  def contact
  	@Title = "Contact"
  	@nav_current = :contact
  end

  def about
  	@Title = "About"
  	@nav_current = :about
  end

  def kale
    @user.focus = 8
    @Title = "Kale Recipes"
  end

  def faq
    @Title = "FAQ"
    @nav_current = :FAQ
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

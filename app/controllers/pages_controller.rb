class PagesController < ApplicationController
  # filter_access_to :all
  
  def home_or_recipes
    if logged_in?
        redirect_to rcpqueries_path 
    else
        redirect_to home_path
    end
  end

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

  # 'spacetaker' produces an empty div--for dialog-testing purposes
  def spacetaker
	@Title = "Spacetaker"
	@nav_current = :Spacetaker
	# The 'partial' parameter indicates to deliver a partial, not the whole page
    respond_to do |format|
      format.html  {
        if @partial = params[:partial]
	      # Render only the partial associated with the page, embedded in the Injector
          render layout: "injector"
        else
          render action: 'spacetaker'
        end
      }
    end
  end

end

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

end

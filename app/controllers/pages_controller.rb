class PagesController < ApplicationController
    def home
  	@Title = "Home"
  	@nav_current = :home
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
	@Title = "Kale Recipes"
  end

  def faq
	@Title = "FAQ"
	@nav_current = :FAQ
  end

end

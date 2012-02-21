class PagesController < ApplicationController
  def home
	@title = "Home"
  end

  def contact
	@title = "Contact"
  end

  def about
	@title = "About"
  end

  def kale
	@title = "Kale Recipes"
  end

end

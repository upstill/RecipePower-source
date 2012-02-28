class PagesController < ApplicationController
  def home
	@title = "Home"
	@navomit = :home
  end

  def contact
	@title = "Contact"
	@navomit = :contact
  end

  def about
	@title = "About"
	@navomit = :about
  end

  def kale
	@title = "Kale Recipes"
  end

end

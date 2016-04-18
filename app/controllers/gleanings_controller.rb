class GleaningsController < ApplicationController
  def new
  end

  def create
    update_and_decorate
    smartrender
  end

  def show
    update_and_decorate
    @gleaning.ensure
  end
end

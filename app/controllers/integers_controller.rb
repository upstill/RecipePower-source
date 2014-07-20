
class IntegersController < ApplicationController

  def index
    # StreamPresenter.new.render # Sets up stream content and stream footer
    do_stream StreamPresenter.new(params)
  end
end

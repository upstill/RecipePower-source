
class IntegersController < ApplicationController

  def index
    # The StreamPresenter is in charge of rendering out a stream, and
    # do_stream (in ApplicationController) streams the content from the presenter, if appropriate
    do_stream StreamPresenter.new(params)
  end
end

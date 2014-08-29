
class IntegersController < ApplicationController

  def index
    # IntegersCache doles out successive integers into divs
    # do_stream (in ApplicationController) streams the content using StreamPresenter, if appropriate
    smartrender unless do_stream IntegersCache, "stream_item"
  end
end

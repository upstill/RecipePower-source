
class IntegersController < ApplicationController

  def index
    # IntegersCache doles out successive integers into divs
    smartrender IntegersCache, "stream_item"
  end
end

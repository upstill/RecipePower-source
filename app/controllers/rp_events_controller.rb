class RpEventsController < ApplicationController
  include Rails.application.routes.url_helpers

  def show
  end

  def self.show_page evt, &block
    block.call evt.shared
  end

  def index
  end

  def new
  end

  def create
  end

  def update
  end

  def destroy
  end
end

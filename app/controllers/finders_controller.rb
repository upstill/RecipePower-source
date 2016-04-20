class FindersController < ApplicationController
  def create
    @finder = Finder.new params[:finder]
    if Finder.where(params[:finder]).exists? # One such already exists
      @finder.errors.add :selector, 'is already in use'
    else
      @decorator = @finder.decorate
      @entity = params[:entity_type].constantize.find params[:entity_id]
      @entity_decorator = @entity.decorate
      FinderServices.new(@finder).testflight @entity
    end
    if resource_errors_to_flash(@finder)
      render :errors
    end
  end
end

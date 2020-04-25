class GleaningsController < ApplicationController
  before_action :set_gleaning, only: [:show, :edit, :update, :destroy]

  def show

  end

  def set_gleaning
    @recipe = Recipe.find_by params.slice(:id)
    @page_ref = @recipe.page_ref
    @page_ref.perform unless @page_ref.gleaned?
    @gleaning = @page_ref.gleaning
  end
end

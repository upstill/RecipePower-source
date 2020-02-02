class RecipeContentsController < ApplicationController
  before_action :set_recipe, only: [:show, :edit, :update, :destroy]
  before_action :login_required

  def edit
    x=2
  end

  def patch
  end

  def create
  end

  def post
  end

  def destroy
  end

  def show
    x=2
  end

  def set_recipe
    @recipe = Recipe.find params[:id]
  end
end

class RecipeContentsController < ApplicationController
  before_action :set_recipe, only: [:show, :edit, :update, :destroy, :annotate]
  before_action :login_required

  def edit
  end

  # Modify the content HTML to mark a selection with a parsing tag
  def annotate
    RecipeContentDecorator.new(@recipe).annotate params[:recipe][:content], params[:recipe][:recipeContents][:token], params[:recipe][:recipeContents][:anchor_path], params[:recipe][:recipeContents][:focus_path]
  end

  def patch
    x=2
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

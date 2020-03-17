require 'parsing_services.rb'
class RecipeContentsController < ApplicationController
  before_action :set_recipe, only: [:show, :edit, :update, :destroy, :annotate]
  before_action :login_required

  def edit
  end

  # Modify the content HTML to mark a selection with a parsing tag
  def annotate
    if params[:recipe][:recipeContents][:parse_path]
      # We simply report the prior annotation back
      @annotation = ParsingServices.parse_on_path *params[:recipe][:recipeContents].values_at(:content, :parse_path)
      @parse_path = nil
    else
      @annotation, @parse_path = ParsingServices.new(@recipe).annotate *params[:recipe][:recipeContents].values_at(:content, :token, :anchor_path, :anchor_offset, :focus_path, :focus_offset)
      x=2
    end
  end

  def patch
    @recipe.recipe_contents = params[:recipe][:recipeContents][:content]
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

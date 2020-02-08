class RecipeContentsController < ApplicationController
  before_action :set_recipe, only: [:show, :edit, :update, :destroy, :annotate]
  before_action :login_required

  def edit
  end

  # Modify the content HTML to mark a selection with a parsing tag
  def annotate
    @annotation = ParsingServices.new(@recipe).annotate *params[:recipe][:recipeContents].values_at(:content, :token, :anchor_path, :anchor_offset, :focus_path, :focus_offset)
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

class RecipePagesController < ApplicationController
  before_action :set_recipe_page, only: [:show, :edit, :update, :destroy]
  before_action :login_required

  # GET /recipe_pages
  def index
    @recipe_pages = RecipePage.all
  end

  # GET /recipe_pages/1
  def show
    @recipe_page.bkg_land(true) unless @recipe_page.content.present?
    # smartrender
  end

  # GET /recipe_pages/new
  def new
    @recipe_page = RecipePage.new
  end

  # GET /recipe_pages/1/edit
  def edit
  end

  # POST /recipe_pages
  def create
    @recipe_page = RecipePage.new(recipe_page_params)

    if @recipe_page.save
      redirect_to @recipe_page, notice: 'Recipe page was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /recipe_pages/1
  def update
    if @recipe_page.update(recipe_page_params)
      redirect_to @recipe_page, notice: 'Recipe page was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /recipe_pages/1
  def destroy
    @recipe_page.destroy
    redirect_to recipe_pages_url, notice: 'Recipe page was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_recipe_page
      @recipe_page = RecipePage.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def recipe_page_params
      params.require(:recipe_page).permit(:content, :page_ref_attributes => [ :id, recipes_attributes: [:title, :id, :anchor_path, :focus_path] ] )
    end
end

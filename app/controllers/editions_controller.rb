class EditionsController < ApplicationController
  before_action :set_edition, only: [:show, :edit, :update, :destroy]

  # GET /editions
  def index
    @editions = Edition.all
  end

  # GET /editions/1
  def show
    @markdown = Redcarpet::Markdown.new Redcarpet::Render::HTML
    @recipient = User.find 1
  end

  # GET /editions/new
  def new
    @edition = Edition.new
  end

  # GET /editions/1/edit
  def edit
  end

  # POST /editions
  def create
    @edition = Edition.new(edition_params)

    if @edition.save
      redirect_to @edition, notice: 'Edition was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /editions/1
  def update
    @edition.published = true if params[:commit].match 'Publish'
    if @edition.update(edition_params)
      redirect_to @edition, notice: 'Edition was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /editions/1
  def destroy
    @edition.destroy
    redirect_to editions_url, notice: 'Edition was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_edition
      @edition = Edition.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def edition_params
      params.require(:edition).permit(:opening, :signoff, :recipe_id, :recipe_before, :recipe_after, :site_id, :site_before, :site_after, :list_id, :list_before, :list_after, :guest_id, :guest_type, :guest_before, :guest_after, :list_id, :list_before, :list_after)
    end
end
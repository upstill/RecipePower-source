class MercuryPagesController < ApplicationController
  before_action :set_mercury_page, only: [:show, :edit, :update, :destroy]

  # GET /mercury_pages
  def index
    @mercury_pages = MercuryPage.all
  end

  # GET /mercury_pages/1
  def show
  end

  # GET /mercury_pages/new
  def new
    @mercury_page = MercuryPage.new
  end

  # GET /mercury_pages/1/edit
  def edit
  end

  # POST /mercury_pages
  def create
    @mercury_page = MercuryPage.new(mercury_page_params)

    if @mercury_page.save
      redirect_to @mercury_page, notice: 'Mercury page was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /mercury_pages/1
  def update
    if @mercury_page.update(mercury_page_params)
      redirect_to @mercury_page, notice: 'Mercury page was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /mercury_pages/1
  def destroy
    @mercury_page.destroy
    redirect_to mercury_pages_url, notice: 'Mercury page was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_mercury_page
      @mercury_page = MercuryPage.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def mercury_page_params
      params.require(:mercury_page).permit(:url, :title, :content, :date_published, :lead_image_url, :domain)
    end
end

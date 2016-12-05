class PageRefsController < ApplicationController
  before_action :set_page_ref, only: [:show, :edit, :update, :destroy]

  # GET /page_refs
  def index
    page_refs = PageRef.all
  end

  # GET /page_refs/1
  def show
  end

  # GET /page_refs/new
  def new
    page_ref = PageRef.new
  end

  # GET /page_refs/1/edit
  def edit
  end

  # POST /page_refs
  def create
    page_ref = PageRef.new(page_ref_params)

    if page_ref.save
      redirect_to page_ref, notice: 'Mercury page was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /page_refs/1
  def update
    if page_ref.update(page_ref_params)
      redirect_to page_ref, notice: 'Mercury page was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /page_refs/1
  def destroy
    page_ref.destroy
    redirect_to page_refs_url, notice: 'Mercury page was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_page_ref
      page_ref = PageRef.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def page_ref_params
      params.require(:page_ref).permit(:url, :title, :content, :date_published, :lead_image_url, :domain)
    end
end

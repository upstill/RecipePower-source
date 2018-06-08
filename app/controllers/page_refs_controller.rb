
class PageRefsController < CollectibleController
  require 'page_ref.rb'
  before_action :set_page_ref, only: [:show, :edit, :update, :destroy]
  before_filter :allow_iframe, only: :tag

  # GET /page_refs
  def index
    page_refs = PageRef.all
  end

  # GET /page_refs/1
  def show
    update_and_decorate
    smartrender
  end

  # GET /page_refs/new
  def new
    @page_ref = PageRef.new kind: 'recipe'
    smartrender
  end

  # GET /page_refs/1/edit
  def edit
    update_and_decorate
    smartrender
  end

  # POST /page_refs
  def create
    @page_ref = PageRefServices.assert(params[:page_ref][:kind], params[:page_ref][:url])
    if @page_ref.errors.any?
      resource_errors_to_flash @page_ref
    else
      @page_ref.bkg_land
      update_and_decorate @page_ref
    end
    respond_to do |format|
      format.json {
        if @page_ref.errors.any?
          render 'application/errors'
        else
          render json: @page_ref.attributes.slice( 'id', 'url', 'kind', 'title' )
        end
      }
      format.html { }
    end
=begin
    if @page_ref.errors.any?
      resource_errors_to_flash @page_ref
      smartrender :new
    else
      redirect_to tag_page_ref_path(@page_ref, :mode => :modal)
    end
=end
    end

=begin
  # PATCH/PUT /page_refs/1
  # Handled in CollectibleController
  def update
    if page_ref.update(page_ref_params)
      redirect_to page_ref, notice: 'Mercury page was successfully updated.'
    else
      render :edit
    end
  end
=end

  # DELETE /page_refs/1
=begin
  # Handled in ApplicationController
  def destroy
    page_ref.destroy
    redirect_to page_refs_url, notice: 'Mercury page was successfully destroyed.'
  end
=end

  def scrape
    begin
      render json: { popup: 'Scraped through ' + PageRef.scrape(params[:first]) + '. Hit reload for next batch.' }
    rescue Exception => e
      render json: { alert: 'Scrape died: ' + e.to_s }
    end
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
